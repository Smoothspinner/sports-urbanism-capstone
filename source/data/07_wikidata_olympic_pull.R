# Pulls Wikidata facts (coordinates, seating capacity, opening year) for the
# Olympic venues. Brian's IOC table has NO Wikipedia links, so we find each
# venue's page by NAME + HOST CITY via the Wikipedia search API, then query
# Wikidata by that article (same approach as 02_wikidata_worldcup_pull.R).
#
# Name matching is noisy, so we filter HARD for precision:
#   1. Keep only matches Wikidata classifies as a sports venue / building type.
#   2. Drop "magnet" pages claimed by 2+ different venues (e.g. many Beijing
#      venues all grabbing Beijing National Stadium) -> untrustworthy, drop all.
#   3. Reject a match if the venue opened AFTER the Games it hosted (impossible).
#   4. Cache the Wikipedia search so re-runs do not re-query 900 pages.
#
# Opening year prefers P1619 (official opening); falls back to P571 (inception)
# when P1619 is blank, since inception is filled far more often on Wikidata.

# Output: data/external/wikidata_olympic_venues.csv

library(tidyverse)
library(httr)
library(jsonlite)

ol <- read_csv("data/processed/olympic_venues_joined.csv", show_col_types = FALSE)
UA <- "TeamGamma-DSE6311-Capstone/1.0 (student project)"
cache_file <- "data/external/olympic_wiki_titles.csv"

# ---- 1. One row per unique venue ----
venues <- ol |>
  mutate(venue_name = str_squish(venue_name),
         host_city  = str_squish(host_city)) |>
  distinct(venue_name, host_city)

# ---- 2. Find best-matching Wikipedia page (cached after the first run) ----
search_title <- function(name, city) {
  r <- tryCatch(
    GET("https://en.wikipedia.org/w/api.php",
        query = list(action = "query", format = "json", list = "search",
                     srsearch = paste(name, city), srlimit = 1, srnamespace = 0),
        add_headers(`User-Agent` = UA)),
    error = function(e) NULL)
  if (is.null(r) || http_error(r)) return(NA_character_)
  hits <- fromJSON(content(r, as = "text", encoding = "UTF-8"),
                   simplifyVector = FALSE)$query$search
  if (length(hits) == 0) return(NA_character_)
  hits[[1]]$title
}

if (file.exists(cache_file)) {
  message("Loading cached Wikipedia titles.")
  venues <- read_csv(cache_file, show_col_types = FALSE)
} else {
  titles <- character(nrow(venues))
  for (i in seq_len(nrow(venues))) {
    titles[i] <- search_title(venues$venue_name[i], venues$host_city[i])
    Sys.sleep(0.2)
    if (i %% 50 == 0) cat("searched", i, "of", nrow(venues), "\n")
  }
  venues$page_title <- titles
  write_csv(venues, cache_file)
}
cat("Found a candidate page for",
    sum(!is.na(venues$page_title)), "of", nrow(venues), "venues.\n")

# ---- 3. Wikipedia article IRI for each matched page ----
iri <- function(t) {
  paste0("https://en.wikipedia.org/wiki/",
         URLencode(str_replace_all(t, " ", "_"), reserved = FALSE)) |>
    str_replace_all("'", "%27")
}
venues <- venues |>
  mutate(article = map_chr(page_title, ~ if (is.na(.x)) NA_character_ else iri(.x)))

# ---- 4. Pull coords, capacity, opening year, inception, AND the item's type(s) ----
article_iris <- unique(na.omit(venues$article))
values_block <- paste0("<", article_iris, ">", collapse = "\n    ")

query <- paste0('
SELECT ?article ?item ?itemLabel ?coords ?capacity ?opened ?inception ?typeLabel WHERE {
  VALUES ?article { ', values_block, ' }
  ?article schema:about ?item .
  OPTIONAL { ?item wdt:P625 ?coords . }
  OPTIONAL { ?item wdt:P1083 ?capacity . }
  OPTIONAL { ?item wdt:P1619 ?opened . }
  OPTIONAL { ?item wdt:P571 ?inception . }
  OPTIONAL { ?item wdt:P31 ?type . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}')

res <- POST("https://query.wikidata.org/sparql",
            body = list(query = query), encode = "form",
            add_headers(Accept = "text/csv", `User-Agent` = UA))
wd <- read_csv(rawToChar(res$content), show_col_types = FALSE)

# ---- 5. Collapse to one row per article, keeping the list of types ----
wd_clean <- wd |>
  group_by(article) |>
  summarise(
    wikidata_id       = first(item),
    wikidata_name     = first(itemLabel),
    types             = paste(unique(na.omit(typeLabel)), collapse = "; "),
    coords            = first(na.omit(coords)),
    capacity_wd       = suppressWarnings(max(capacity, na.rm = TRUE)),
    opened_year_p1619 = suppressWarnings(min(as.integer(substr(opened, 1, 4)), na.rm = TRUE)),
    opened_year_p571  = suppressWarnings(min(as.integer(substr(inception, 1, 4)), na.rm = TRUE)),
    .groups = "drop") |>
  mutate(across(c(opened_year_p1619, opened_year_p571, capacity_wd),
                ~ ifelse(is.infinite(.x), NA, .x)),
         opened_year = coalesce(opened_year_p1619, opened_year_p571),
         opened_year_source = case_when(!is.na(opened_year_p1619) ~ "P1619",
                                        !is.na(opened_year_p571)  ~ "P571",
                                        TRUE                      ~ NA_character_))

venues <- venues |> left_join(wd_clean, by = "article")

# ---- 6. FILTER 1: keep only matches that are actually a venue/building ----
venue_types <- paste("stadium|arena|sports venue|velodrome|aquatic|swimming",
                     "pool|gymnasium|sports hall|sports ground|sports complex",
                     "tennis|athletic|race ?track|hippodrome|ice rink|golf",
                     "sports centre|sports center|shooting range|pitch|field",
                     sep = "|")
venues <- venues |>
  mutate(is_venue = !is.na(types) & str_detect(str_to_lower(types), venue_types))

# ---- 6b. FILTER 2: drop "magnet" pages that 2+ different venues matched ----
dupe_pages <- venues |>
  filter(is_venue, !is.na(page_title)) |>
  count(page_title) |> filter(n > 1) |> pull(page_title)
cat("Dropping", length(dupe_pages), "magnet pages claimed by multiple venues.\n")
venues <- venues |>
  mutate(is_venue = is_venue & !(page_title %in% dupe_pages))

# Blank facts from anything we are not keeping
venues <- venues |>
  mutate(coords              = if_else(is_venue, coords, NA_character_),
         capacity_wd         = if_else(is_venue, as.numeric(capacity_wd), NA_real_),
         opened_year         = if_else(is_venue, as.numeric(opened_year), NA_real_),
         opened_year_source  = if_else(is_venue, opened_year_source, NA_character_))

# ---- 7. Attach to every row; FILTER 3: reject if it opened after its Games ----
out <- ol |>
  mutate(venue_name = str_squish(venue_name), host_city = str_squish(host_city)) |>
  left_join(venues |> select(venue_name, host_city, page_title, types,
                             wikidata_id, wikidata_name, coords,
                             capacity_wd, opened_year, opened_year_source),
            by = c("venue_name", "host_city")) |>
  mutate(too_new             = !is.na(opened_year) & opened_year > games_year,
         coords              = if_else(too_new, NA_character_, coords),
         capacity_wd         = if_else(too_new, NA_real_, capacity_wd),
         opened_year         = if_else(too_new, NA_real_, opened_year),
         opened_year_source  = if_else(too_new, NA_character_, opened_year_source)) |>
  select(-too_new)

write_csv(out, "data/external/wikidata_olympic_venues.csv")

# ---- 8. Coverage + spot-check (from the final, filtered table) ----
usable <- out |>
  filter(!is.na(coords) | !is.na(capacity_wd) | !is.na(opened_year)) |>
  distinct(venue_name, host_city, .keep_all = TRUE)
cat("\nUnique venues:            ", n_distinct(paste(out$venue_name, out$host_city)), "\n")
cat("Venues with a usable fact:", nrow(usable), "\n")
cat("  with coordinates:       ", sum(!is.na(usable$coords)), "\n")
cat("  with capacity:          ", sum(!is.na(usable$capacity_wd)), "\n")
cat("  with opening year:      ", sum(!is.na(usable$opened_year)), "\n")
cat("    from P1619:           ", sum(usable$opened_year_source == "P1619", na.rm = TRUE), "\n")
cat("    from P571 fallback:   ", sum(usable$opened_year_source == "P571", na.rm = TRUE), "\n\n")
cat("Spot-check, sorted by capacity:\n")
usable |> arrange(desc(capacity_wd)) |>
  select(venue_name, host_city, games_year, page_title, capacity_wd, opened_year, opened_year_source) |>
  print(n = 30)
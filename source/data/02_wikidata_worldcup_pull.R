# Pulls Wikidata facts (coordinates, capacity, opening/demolition dates,
# tenants) for all 240 World Cup stadiums. Matches by Wikipedia link,
# first asking Wikipedia for each page's current title so renamed
# stadiums still match. Output: data/external/

library(tidyverse)
library(httr)
library(jsonlite)

stadiums <- read_csv("data/raw/stadiums.csv", show_col_types = FALSE)

# ---- 1. Turn each link into a plain page title ----
stadiums <- stadiums |>
  mutate(page_title = stadium_wikipedia_link |>
           str_remove("^https?://en\\.wikipedia\\.org/wiki/") |>
           map_chr(URLdecode) |>
           str_replace_all("_", " "))

# ---- 2. Ask Wikipedia for the current name of every page ----
# (Stadiums get renamed; old links redirect. This follows the redirect.)
lookup <- list()
for (batch in split(unique(stadiums$page_title),
                    ceiling(seq_along(unique(stadiums$page_title)) / 50))) {
  r <- GET("https://en.wikipedia.org/w/api.php",
           query = list(action = "query", format = "json",
                        redirects = 1, titles = paste(batch, collapse = "|")),
           add_headers(`User-Agent` = "TeamGamma-DSE6311-Capstone/1.0"))
  j <- fromJSON(content(r, as = "text", encoding = "UTF-8"),
                simplifyVector = FALSE)
  for (x in j$query$normalized) lookup[[x$from]] <- x$to
  for (x in j$query$redirects)  lookup[[x$from]] <- x$to
  Sys.sleep(0.5)
}

follow <- function(t) {
  seen <- character()
  while (!is.null(lookup[[t]]) && !(t %in% seen)) {
    seen <- c(seen, t); t <- lookup[[t]]
  }
  t
}

stadiums <- stadiums |>
  mutate(canonical_title = map_chr(page_title, follow),
         article_iri = paste0("https://en.wikipedia.org/wiki/",
                              map_chr(str_replace_all(canonical_title, " ", "_"),
                                      ~ URLencode(.x, reserved = FALSE))))
stadiums <- stadiums |>
  mutate(article_iri = str_replace_all(article_iri, "'", "%27"))

# ---- 3. Pull the facts from Wikidata ----
values_block <- paste0("<", unique(stadiums$article_iri), ">", collapse = "\n    ")

query <- paste0('
SELECT ?article ?item ?itemLabel ?coords ?capacity ?opened ?demolished ?occupantLabel WHERE {
  VALUES ?article { ', values_block, ' }
  ?article schema:about ?item .
  OPTIONAL { ?item wdt:P625 ?coords . }
  OPTIONAL { ?item wdt:P1083 ?capacity . }
  OPTIONAL { ?item wdt:P1619 ?opened . }
  OPTIONAL { ?item wdt:P576 ?demolished . }
  OPTIONAL { ?item wdt:P466 ?occupant . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}')

res <- POST("https://query.wikidata.org/sparql",
            body = list(query = query), encode = "form",
            add_headers(Accept = "text/csv",
                        `User-Agent` = "TeamGamma-DSE6311-Capstone/1.0"))

wd <- read_csv(rawToChar(res$content), show_col_types = FALSE)

# ---- 4. Collapse to one row per stadium and save ----
wd_clean <- wd |>
  group_by(article) |>
  summarise(
    wikidata_id     = first(item),
    wikidata_name   = first(itemLabel),
    coords          = first(na.omit(coords)),
    capacity_wd     = suppressWarnings(max(capacity, na.rm = TRUE)),
    opened_year     = suppressWarnings(min(as.integer(substr(opened, 1, 4)), na.rm = TRUE)),
    demolished_year = suppressWarnings(min(as.integer(substr(demolished, 1, 4)), na.rm = TRUE)),
    tenants         = paste(unique(na.omit(occupantLabel)), collapse = "; "),
    .groups = "drop") |>
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.x), NA, .x)))

out <- stadiums |>
  left_join(wd_clean, by = c("article_iri" = "article"))

write_csv(out, "data/external/wikidata_worldcup_stadiums.csv")

matched <- sum(!is.na(out$wikidata_id))
cat("Matched", matched, "of", nrow(out), "stadiums.\n")
if (matched < nrow(out)) {
  cat("Still unmatched:\n")
  print(out |> filter(is.na(wikidata_id)) |>
          select(stadium_name, country_name), n = 50)
}
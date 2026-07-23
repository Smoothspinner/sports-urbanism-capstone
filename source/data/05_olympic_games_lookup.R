# Hand-built lookup: one row per Olympic Games edition (summer + winter,
# 1896-2022), giving the host country and the year the Games were AWARDED.
# This is the Olympic-side twin of 03_award_years.R. It is keyed to the exact
# "Games Year" + "Host City" strings in Brian's VenueReportsV2.xlsx ("At A
# Glance" sheet) so 06_join_olympic_data.R can join on those two columns.
#
# Award year = the year the IOC session elected the host (the Olympic analogue
# of the bid/award year we used on the World Cup side). Where a Games was moved
# from its original host, we use the year the ACTUAL host was confirmed, same
# rule as the World Cup side (e.g. St. Louis 1904, London 1908, Innsbruck 1976).
#
# Sources: Wikipedia "List of Olympic Games host cities" and each edition's
# IOC session record (verified 7/22/2026).
#
# precision = "exact"  -> IOC election year is well documented
#             "approximate" -> host moved late or early-era records are fuzzy
#
# Dead-country note: host_country is stored as it was AT THE TIME. Converting to
# a country code, and the West Germany -> Germany / USSR & Yugoslavia -> NA
# decision, happens in 06_join_olympic_data.R (kept there so this file stays a
# plain reference table).

library(tidyverse)

olympic_games <- tribble(
  ~games_year, ~host_city,                ~host_country,    ~award_year, ~precision,
  # ---- Summer Games ----
  1896, "Athens",                 "Greece",         1894, "exact",       # IOC Congress, Paris, Jun 1894
  1900, "Paris",                  "France",         1894, "exact",       # same 1894 congress
  1904, "St. Louis",              "United States",  1903, "approximate", # moved from Chicago, confirmed Feb 1903
  1908, "London",                 "United Kingdom", 1906, "approximate", # moved from Rome after Vesuvius, 1906
  1912, "Stockholm",              "Sweden",         1909, "exact",       # IOC session Berlin, 1909
  1920, "Antwerp",                "Belgium",        1914, "exact",       # IOC session Paris, Jun 1914
  1924, "Paris",                  "France",         1921, "exact",       # IOC session Lausanne, 1921
  1928, "Amsterdam",              "Netherlands",    1921, "exact",       # same 1921 session
  1932, "Los Angeles",            "United States",  1923, "exact",       # IOC session Rome, 1923
  1936, "Berlin",                 "Germany",        1931, "exact",       # IOC session Barcelona/postal, 1931
  1948, "London",                 "United Kingdom", 1946, "exact",       # IOC postal vote, 1946
  1952, "Helsinki",               "Finland",        1947, "exact",       # IOC session Stockholm, 1947
  1956, "Melbourne / Stockholm",  "Australia",      1949, "exact",       # awarded Melbourne, Rome 1949 (see note)
  1960, "Rome",                   "Italy",          1955, "exact",       # IOC session Paris, 1955
  1964, "Tokyo",                  "Japan",          1959, "exact",       # IOC session Munich, 1959
  1968, "Mexico City",            "Mexico",         1963, "exact",       # IOC session Baden-Baden, 1963
  1972, "Munich",                 "West Germany",   1966, "exact",       # IOC session Rome, Apr 1966
  1976, "Montreal",               "Canada",         1970, "exact",       # IOC session Amsterdam, 1970
  1980, "Moscow",                 "Soviet Union",   1974, "exact",       # IOC session Vienna, 1974
  1984, "Los Angeles",            "United States",  1978, "exact",       # IOC session Athens, 1978
  1988, "Seoul",                  "South Korea",    1981, "exact",       # IOC session Baden-Baden, 1981
  1992, "Barcelona",              "Spain",          1986, "exact",       # IOC session Lausanne, Oct 1986
  1996, "Atlanta",                "United States",  1990, "exact",       # IOC session Tokyo, 1990
  2000, "Sydney",                 "Australia",      1993, "exact",       # IOC session Monte Carlo, 1993
  2004, "Athens",                 "Greece",         1997, "exact",       # IOC session Lausanne, 1997
  2008, "Beijing",                "China",          2001, "exact",       # IOC session Moscow, 2001
  2012, "London",                 "United Kingdom", 2005, "exact",       # IOC session Singapore, 2005
  2016, "Rio de Janeiro",         "Brazil",         2009, "exact",       # IOC session Copenhagen, 2009
  2020, "Tokyo",                  "Japan",          2013, "exact",       # IOC session Buenos Aires, 2013
  2022, "Beijing",                "China",          2015, "exact",       # IOC session Kuala Lumpur, 2015 (winter)
  # ---- Winter Games ----
  1924, "Chamonix",               "France",         1922, "approximate", # winter sports week agreed 1921-22
  1928, "St. Moritz",             "Switzerland",    1926, "exact",       # IOC session Lisbon, 1926
  1932, "Lake Placid",            "United States",  1929, "exact",       # IOC session Lausanne, 1929
  1936, "Garmisch-Partenkirchen", "Germany",        1933, "exact",       # IOC session Vienna, 1933
  1948, "St. Moritz",             "Switzerland",    1946, "exact",       # IOC session Lausanne, 1946
  1952, "Oslo",                   "Norway",         1947, "exact",       # IOC session Stockholm, 1947
  1956, "Cortina d’Ampezzo", "Italy",          1949, "exact",       # IOC session Rome, 1949
  1960, "Squaw Valley",           "United States",  1955, "exact",       # IOC session Paris, 1955
  1964, "Innsbruck",              "Austria",        1959, "exact",       # IOC session Munich, 1959
  1968, "Grenoble",               "France",         1964, "exact",       # IOC session Innsbruck, Jan 1964
  1972, "Sapporo",                "Japan",          1966, "exact",       # IOC session Rome, Apr 1966
  1976, "Innsbruck",              "Austria",        1973, "approximate", # moved from Denver after 1972 withdrawal
  1980, "Lake Placid",            "United States",  1974, "exact",       # IOC session Vienna, 1974
  1984, "Sarajevo",               "Yugoslavia",     1978, "exact",       # IOC session Athens, 1978
  1988, "Calgary",                "Canada",         1981, "exact",       # IOC session Baden-Baden, 1981
  1992, "Albertville",            "France",         1986, "exact",       # IOC session Lausanne, Oct 1986
  1994, "Lillehammer",            "Norway",         1988, "exact",       # IOC session Seoul, 1988
  1998, "Nagano",                 "Japan",          1991, "exact",       # IOC session Birmingham, 1991
  2002, "Salt Lake City",         "United States",  1995, "exact",       # IOC session Budapest, 1995
  2006, "Torino",                 "Italy",          1999, "exact",       # IOC session Seoul, 1999
  2010, "Vancouver",              "Canada",         2003, "exact",       # IOC session Prague, 2003
  2014, "Sochi",                  "Russia",         2007, "exact",       # IOC session Guatemala City, 2007
  2018, "PyeongChang",            "South Korea",    2011, "exact"        # IOC session Durban, 2011
)

# 1956 note: the Games were awarded to Melbourne; equestrian events were held
# separately in Stockholm, Sweden (Australian quarantine). We treat the whole
# edition as hosted by Australia and flag the Stockholm equestrian venues as a
# known limitation rather than splitting the country.

write_csv(olympic_games, "data/external/olympic_games_lookup.csv")
cat("Wrote", nrow(olympic_games), "Olympic Games editions.\n")

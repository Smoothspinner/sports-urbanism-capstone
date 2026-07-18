# Hand-built lookup: the year each World Cup was awarded to its host.
# Needed for the newly_built definition (venue existed before award = existing).
# Keyed to tournament_id from Fjelstul's tournaments.csv.
# Sources: Wikipedia "List of FIFA World Cup hosts" and
# "FIFA Women's World Cup hosts" (both verified 7/17/2026).
# Notes: 1986 was re-awarded to Mexico in 1983 after Colombia withdrew;
# 2003 was moved to the US in 2003 after SARS; we use the actual host's
# award year. 1991 and 1995 women's dates are poorly documented and
# marked approximate.

library(tidyverse)

award_years <- tribble(
  ~tournament_id, ~award_year, ~precision,
  "WC-1930", 1929, "exact",        # FIFA Congress, Barcelona, May 1929
  "WC-1934", 1932, "exact",        # ratified Stockholm, May 1932
  "WC-1938", 1936, "exact",        # FIFA Congress, Berlin, Aug 1936
  "WC-1950", 1946, "exact",        # Luxembourg City, Jul 1946
  "WC-1954", 1946, "exact",        # same meeting as 1950
  "WC-1958", 1950, "exact",        # awarded unopposed, Jun 1950
  "WC-1962", 1956, "exact",        # Lisbon, Jun 1956
  "WC-1966", 1960, "exact",        # Rome, Aug 1960
  "WC-1970", 1964, "exact",        # Tokyo, Oct 1964
  "WC-1974", 1966, "exact",        # London, Jul 1966 (triple award)
  "WC-1978", 1966, "exact",        # London, Jul 1966 (triple award)
  "WC-1982", 1966, "exact",        # London, Jul 1966 (triple award)
  "WC-1986", 1983, "exact",        # re-award to Mexico, May 1983
  "WC-1990", 1984, "exact",        # Zurich, May 1984
  "WC-1991", 1988, "approximate",  # settled after 1988 test tournament
  "WC-1994", 1988, "exact",        # Zurich, Jul 1988
  "WC-1995", 1993, "approximate",  # short-notice swap from Bulgaria
  "WC-1998", 1992, "exact",        # Zurich, Jul 1992
  "WC-1999", 1996, "exact",        # awarded 31 May 1996
  "WC-2002", 1996, "exact",        # same day as WWC 1999 award
  "WC-2003", 2003, "exact",        # moved from China, May 2003
  "WC-2006", 2000, "exact",        # Zurich, Jul 2000
  "WC-2007", 2003, "exact",        # granted to China after 2003 move
  "WC-2010", 2004, "exact",        # Zurich, May 2004
  "WC-2011", 2007, "exact",        # awarded 30 Oct 2007
  "WC-2014", 2007, "exact",        # confirmed 30 Oct 2007
  "WC-2015", 2011, "exact",        # awarded Mar 2011
  "WC-2018", 2010, "exact",        # awarded 2 Dec 2010
  "WC-2019", 2015, "exact",        # awarded 19 Mar 2015
  "WC-2022", 2010, "exact"         # awarded 2 Dec 2010
)

write_csv(award_years, "data/external/worldcup_award_years.csv")
cat("Wrote", nrow(award_years), "award years.\n")
library(tidyverse)
library(lubridate)
library(rcrossref)

## Crossref is very efficient at returning metadata

issns_primary = c('0031-8248', # Philosophy of Science
          '0039-3681', # Studies A
          '1355-2198', # Studies B
          '1369-8486', # Studies C
          '0039-7857', # Synthese
          '0169-3867', # Biology and Philosophy
          '0007-0882', # BJPS
          '2152-5188', # HOPOS
          '1879-4912', # EJPS
          '1063-6145', # Perspectives on Science
          '1949-0739' # PTP Bio
)
issns_secondary = c(
          ## ----- Boundary btwn phil sci and analytic
          '0165-0106', # Erkenntnis
          '0269-1728', # Social Epistemology
          ## ----- Less prominent phil sci
          '0269-8595', # International Studies in the Philosophy of Science
          '1233-1821', # Foundations of Science
          '0815-0796', # Metascience
          '0048-3931', # Philosophy of the Social Sciences
          '1350-178X', # Journal of Economic Methodology
          '0015-9018', # Foundations of Physics
          '0925-4560', # Journal of General Philosophy of Science
          '2069-0533', # Logos and Episteme
          ## ----- Feminist phil
          '0887-5367', # Hypatia
          '0097-9740', # Signs
          ## ----- Analytic
          '0022-362X', # J Phil
          '0031-8116', # Phil Studies
          '0031-8205' # PPR
)

issns = tibble(issn = c(issns_primary, issns_secondary), 
       journal_group = c(rep('primary', length(issns_primary)), 
                         rep('secondary', length(issns_secondary))))

## Erkenntnis is complicated.  The prewar run is almost entirely in German.  The postwar run is almost entirely in English, but includes a lot of non-science analytic philosophy (e.g., political philosophy papers by G.A. Cohen and Harsanyi) and some individuals who might be placed on the margins between philosophy of science and other areas (e.g., Davidson)

journal_data = issns %>%
    pull(issn) %>%
    map(cr_journals) %>%
    transpose() %>%
    .$data %>%
    bind_rows() %>%
    select(title, issn, publisher, 
           total_dois) %>%
    bind_cols(issns) ## clunky, but necessary bc CrossRef doesn't necessarily return the ISSN we gave it

## 72k total papers
# sum(journal_data$total_dois)

## Takes about 15 minutes
system.time({
    results = cr_journals(issn = journal_data$issn, works = TRUE, 
                    limit = 1000,
                    cursor = '*', cursor_max = 10000)
})

## About 58k papers
papers = results$data %>%
    separate(ISSN, c('issn', 'issn2'), sep = ',') %>% 
    select(-issn2) %>%
    left_join({
        journal_data %>%
            gather(key = 'key', value = 'issn', issn, issn1) %>%
            select(issn, journal_group)
    }, by = 'issn') %>%
    mutate(pub_date = parse_date_time(issued, c('ym', 'y', 'ymd')), 
           pub_year = year(pub_date))

## Papers published in each year
ggplot(papers, aes(pub_year, fill = journal_group)) + geom_bar()


## 29k distinct author names
## 7.5k names (~70%) only have 1 paper
author_counts = papers %>%
    select(doi = DOI, author, journal_group) %>%
    filter(!map_lgl(papers$author, is.null)) %>%
    unnest() %>%
    select(doi:family) %>%
    filter(!duplicated(.)) %>%
    count(given, family, journal_group) %>%
    spread(journal_group, n, fill = 0) %>%
    arrange(family)

## Write output ----------
saveRDS(papers, file = '01_papers.rds')
write_csv(author_counts, path = '01_authors.csv')

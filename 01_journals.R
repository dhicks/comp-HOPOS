## Use CrossRef to get metadata for journal articles
library(tidyverse)
library(lubridate)
library(rcrossref)

## Bc some philosophy of science is published elsewhere (especially before the phil sci/analytic split began), need to grab both "primary" phil sci journals + "secondary" journals that have a little phil sci (and lots of irrelevant stuff)
## To filter out the irrelevant stuff later, use inclusion rules for authors after de-duping, eg, need at least 2 papers in primary journals

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
       publication_group = c(rep('primary', length(issns_primary)), 
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
    ## clunky, but necessary bc CrossRef doesn't necessarily return the ISSN we gave it
    bind_cols(issns)

## 72k total papers
# sum(journal_data$total_dois)

## Takes about 15 minutes
system.time({
    results = cr_journals(issn = journal_data$issn, works = TRUE, 
                    limit = 1000,
                    cursor = '*', cursor_max = 10000, 
                    .progress = 'text')
})

papers = results$data %>%
    filter(type != 'journal') %>%
    separate(ISSN, c('ISSN', 'issn2'), sep = ',', fill = 'right') %>% 
    select(-issn2) %>%
    ## Left join to get publication_group
    left_join({
        journal_data %>%
            gather(key = 'key', value = 'ISSN', issn, issn1) %>%
            select(ISSN, publication_group)
    }, by = 'ISSN') %>%
    mutate(publication_series = container.title)

## Confirm no papers w/ missing publication group
filter(papers, is.na(publication_group))

## Write output ----------
write_rds(papers, path = '01_papers.rds')

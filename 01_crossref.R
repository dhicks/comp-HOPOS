library(tidyverse)
library(lubridate)
library(rcrossref)

## Crossref is very efficient at returning metadata

issns = c('0031-8248', # Philosophy of Science
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
          # ## -----
          # '0165-0106', # Erkenntnis
          # '0269-1728', # Social Epistemology
          # ## -----
          # '0269-8595', # International Studies in the Philosophy of Science
          # '1233-1821', # Foundations of Science
          # '0815-0796', # Metascience
          # '0048-3931', # Philosophy of the Social Sciences
          # '1350-178X', # Journal of Economic Methodology
          # '0015-9018', # Foundations of Physics
          # '0925-4560', # Journal of General Philosophy of Science
          # '2069-0533', # Logos and Episteme
          # ## -----
          # '0887-5367' # Hypatia
)

## Erkenntnis is complicated.  The prewar run is almost entirely in German.  The postwar run is almost entirely in English, but includes a lot of non-science analytic philosophy (e.g., political philosophy papers by G.A. Cohen and Harsanyi) and some individuals who might be placed on the margins between philosophy of science and other areas (e.g., Davidson)

journal_data = issns %>%
    map(cr_journals) %>%
    transpose() %>%
    .$data %>%
    bind_rows() %>%
    select(title, issn, publisher, 
           total_dois)

## Takes about 3 minutes
system.time(
    {results = cr_journals(issn = issns, works = TRUE, 
                    limit = 1000,
                    cursor = '*', cursor_max = 10000)})

## About 23k papers
papers = results$data


## Papers published in each year
papers = papers %>%
    mutate(pub_date = parse_date_time(issued, c('ym', 'y', 'ymd')), 
           pub_year = year(pub_date))

ggplot(papers, aes(pub_year, fill = container.title)) + geom_bar()


## 11.6k distinct author names
## 7.5k names (~70%) only have 1 paper
papers$author %>%
    `names<-`(papers$DOI) %>%
    bind_rows(.id = 'DOI') %>%
    count(given, family) %>%
    arrange(family) %>% View
    write_csv('01_names_cr.csv')

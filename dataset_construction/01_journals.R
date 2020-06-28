## Use CrossRef to get metadata for journal articles
library(tidyverse)
library(lubridate)
library(rcrossref)

library(tictoc)

## Check whether crossref_email has been registered
if (Sys.getenv('crossref_email') == '') {
    stop('crossref_email was missing/empty. 
         Follow the instructions at <https://github.com/ropensci/rcrossref#register-for-the-polite-pool>.')
}

## Bc some philosophy of science is published elsewhere (especially before the phil sci/analytic split began), need to grab both "primary" phil sci journals + "secondary" journals that have a little phil sci (and lots of other stuff)
## To filter out the other stuff later, use inclusion rules for authors after de-duping, eg, need at least 2 papers in primary journals

issns_primary = c('0031-8248', # Philosophy of Science
                  '0270-8647', # PSA Proceedings
                  '0169-3867', # Biology and Philosophy
                  '0007-0882', # BJPS
                  '1464-3537', ## Need both ISSNs to get all BJPS results
                  '2152-5188', # HOPOS
                  '1879-4912', # EJPS
                  '1063-6145', # Perspectives on Science
                  '1949-0739', # PTP Bio
                  '0269-8595', # International Studies in the Philosophy of Science
                  '0925-4560', # Journal of General Philosophy of Science
                  '0048-3931' # Philosophy of the Social Sciences
)
issns_secondary = c(
    ## ----- Boundary btwn phil sci and other disciplines
    '1233-1821', # Foundations of Science
    '0015-9018', # Foundations of Physics
    '1350-178X', # Journal of Economic Methodology
    '2069-0533', # Logos and Episteme
    '0926-7220', # Science and Education
    '1474-0664', # Science in Context
    '0162-2439', # ST&HV
    '1913-0465', # Spontaneous Generations
    '0039-3681', # Studies A
    '1355-2198', # Studies B
    '1369-8486' # Studies C
)
issns_feminist = c(
    ## ----- Feminist phil
    '0887-5367', # Hypatia
    '0097-9740' # Signs
)
issns_analytic = c(
    ## ----- Boundary btwn phil sci and analytic
    '0165-0106', # Erkenntnis
    '0039-7857', # Synthese
    '0269-1728', # Social Epistemology
    ## ----- Analytic
    #'0003-0481' # APQ - not indexed by CrossRef
    '0003-2638', # Analysis
    '2330-4014', # Ergo
    '1742-3600', # Episteme
    '0022-362X', # J Phil
    '1467-9973', # Metaphilosophy
    '0026-9662', # Monist
    '0026-4423', # Mind
    '0029-4624', # Nous
    '0031-8108', # Phil Review
    '0031-8116', # Phil Studies
    '0031-8205', # PPR
    '1467-9264', # Proc. Aristotelean Soc.
    '1572-8749' # Topoi
)

## NB Hypatia has articles with multiple DOIs, eg, 10.1111/j.1527-2001.2000.tb01079.x, 10.1353/hyp.2000.0002, and 10.2979/hyp.2000.15.1.43
## Many of the "hyp" DOIs are duplicates (or leftover from before Hypatia was published by Wylie?)
## But, eg, 10.1353/hyp.2005.0132 is NOT a duplicate of any other record
## It looks like these are book reviews:  Wylie groups the book reviews in an issue together under a single DOI
## TRY:  only use the 1. Hypatia ISSN, then filter out the "hyp" DOIs

issns = tibble(issn = c(issns_primary, issns_secondary, 
                        issns_feminist, issns_analytic), 
               publication_group = c(rep('primary', length(issns_primary)), 
                                     rep('secondary', length(issns_secondary)), 
                                     rep('feminist', length(issns_feminist)), 
                                     rep('analytic', length(issns_analytic))))

## A few articles return with an ISSN that doesn't show up in the issns table
variant_issns = tribble(
    ~issn, ~publication_group, 
    '0026-1068', 'analytic',
    '0066-7374', 'analytic', 
    '0269-8897', 'secondary', 
    '0000-0000', 'secondary', 
    '0167-7411', 'analytic'
)

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

## ~24 minutes
tic()
results = cr_journals(issn = journal_data$issn1, works = TRUE, 
                          limit = 1000,
                          cursor = '*', cursor_max = 20000, 
                          .progress = 'text')
toc()

papers = results$data %>% 
    rename(doi = DOI, issn = ISSN) %>%
    filter(type != 'journal', type != 'journal-issue', 
           ## Deal w/ the Hypatia duplication issue noted above
           !str_detect(doi, 'hyp')) %>%
    separate(issn, c('issn', 'issn2'), sep = ',', fill = 'right') %>% 
    select(-issn2) %>%
    ## Left join to get publication_group
    left_join({
        journal_data %>%
            gather(key = 'key', value = 'issn', issn, issn1) %>%
            select(issn, publication_group) %>%
            bind_rows(variant_issns)
    }, by = 'issn') %>%
    rename(publication_series = container.title) %>%
    filter(!duplicated(.))

## Confirm no papers w/ missing publication group, publication series, DOI
filter(papers, is.na(publication_group)) %>%
    count(publication_series, issn)
filter(papers, is.na(publication_series))
filter(papers, is.na(doi))

## Write output ----------
papers %>%
    count(publication_series) %>%
    write_csv('../data/01_journal_data.csv')
write_rds(papers, path = '../data/01_papers.rds')

## Upstream CSVs were retrieved using SpringerLink on 2017-12-23
## https://link.springer.com/search?facet-series=%225710%22&facet-content-type=%22Book%22&showAll=true
## Then simply click the downward-arrow "download search results" button

library(tidyverse)
library(stringr)
library(xml2)
library(foreach)
library(rcrossref)

## Check whether crossref_email has been registered
if (Sys.getenv('crossref_email') == '') {
    stop('crossref_email was missing/empty. 
         Follow the instructions at <https://github.com/ropensci/rcrossref#register-for-the-polite-pool>.')
}

## Load upstream CSVs ----------
boston_df = read_csv('../data/00_Boston.csv') %>%
    mutate(URL = str_replace(URL, 'http', 'https'))
western_df = read_csv('../data/00_Western_Ontario.csv') %>%
    mutate(URL = str_replace(URL, 'http', 'https'))

book_series_df = bind_rows(list('Boston SH&PS' = boston_df, 
                                'Western Ontario SH&PS' = western_df),
                           .id = 'publication_series') %>%
    mutate(publication_group = 'primary')

## Scrape TOCs from Springer ----------
## Basic idea here is that the CSVs include URLs for TOC pages
## These pages list chapters, w/ DOIs embedded in the links
parse_dois = function(response) {
    dois = xml_find_all(response, 
                        '//li[@class="chapter-item content-type-list__item"]') %>%
        xml_find_first('.//a[@class="content-type-list__link u-interface-link gtm-chapter-link"]') %>%
        xml_attr('href') %>%
        str_extract('10.*')
    return(dois)
}

scrape_springer = function(this_url) {
    ## Avoid attracting too much attention
    Sys.sleep(.5)
    response = read_html(this_url)
    dois = parse_dois(response)
    
    ## Springer returns 19 results per page
    ## If we have <19, we're good to go
    if (length(dois) < 19) {
        result = tibble(book_url = this_url, 
                        ch_doi = dois)
        return(result)
    } else {
        ## If more, check for a "next page" URL
        these_results = tibble(book_url = this_url, ch_doi = dois)
        next_url = response %>%
            xml_find_first('//a[@class="test-pagination-next c-pagination__next"]') %>%
            xml_attr('href') %>%
            str_c('https://link.springer.com', .)
        if (is.na(next_url)) {
            ## If not found, then just return
            return(these_results)
        } else {
            ## Otherwise go to the next page
            ## recursion yay
            other_results = scrape_springer(next_url)
            combined_results = bind_rows(these_results, other_results)
            return(combined_results) 
        }
    }
}

# system.time({
#      springer_df = foreach(this_url = book_series_df$URL, 
#                       .combine = bind_rows, 
#                       .multicombine = TRUE, 
#                       .verbose = FALSE) %do% 
#     scrape_springer(this_url)
# })
system.time({
    springer_df = book_series_df %>%
        pull(URL) %>%
        plyr::ldply(scrape_springer, .progress = 'text')
})

## Confirm we have results for all books in book_series_df
springer_df %>%
    mutate(first_page_url = str_extract(book_url, '[^?]*')) %>% 
    anti_join(book_series_df, by = c('first_page_url' = 'URL'))

## Confirm we don't have any weird clusters of lengths suggesting cutoffs
springer_df %>%
    mutate(first_page_url = str_extract(book_url, '[^?]*')) %>%
    count(first_page_url) %>%
    # ggplot(aes(first_page_url, n)) + geom_point()
    ggplot(aes(n)) + geom_bar()

## Confirm there aren't any NAs for the DOIs
springer_df %>% 
    pull(ch_doi) %>% 
    is.na() %>% 
    table()

## Retrieve chapter metadata from CrossRef ----------
## Takes ~43 seconds / 100 DOIs
## So ~40 minutes for all ~5.5k
system.time({
    cr_df = cr_works(springer_df$ch_doi, .progress = 'text')
})

springer_books_df = cr_df$data %>%
    ## Join w/ ch-level DOIs, so we can see what DOIs weren't in CR
    right_join(springer_df, by = c('DOI' = 'ch_doi')) %>%
    ## And join w/ the original DF to track book series
    left_join(select(book_series_df, 
                     URL, publication_group, publication_series), 
              by = c('book_url' = 'URL'))

## Save results ----------
write_rds(springer_books_df, path = '../data/02_springer_books.rds')

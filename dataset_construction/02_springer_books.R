## Upstream CSVs were retrieved using SpringerLink on 2017-12-23
## https://link.springer.com/search?facet-series=%225710%22&facet-content-type=%22Book%22&showAll=true
## Then simply click the downward-arrow "download search results" button

library(tidyverse)
library(stringr)
library(xml2)
library(foreach)
library(rcrossref)

library(tictoc)
library(assertthat)

## Check whether crossref_email has been registered
if (Sys.getenv('crossref_email') == '') {
    stop('crossref_email was missing/empty. 
         Follow the instructions at <https://github.com/ropensci/rcrossref#register-for-the-polite-pool>.')
}

## Load upstream CSVs ----------
data_folder = file.path('..', 'data')

boston_df = read_csv(file.path(data_folder, '00_Boston.csv')) %>%
    mutate(URL = str_replace(URL, 'http', 'https'))
western_df = read_csv(file.path(data_folder, '00_Western_Ontario.csv')) %>%
    mutate(URL = str_replace(URL, 'http', 'https'))

book_series_df = bind_rows(list('Boston SH&PS' = boston_df, 
                                'Western Ontario SH&PS' = western_df),
                           .id = 'publication_series') %>%
    mutate(publication_group = 'primary')

## Scrape TOCs from Springer ----------
## Basic idea here is that the CSVs include URLs for TOC pages
## These pages list chapters, w/ DOIs embedded in the links
parse_dois = function(response) {
    dois = response %>% 
        xml_find_all('//li[@class="chapter-item content-type-list__item"]') %>%
        xml_find_first('.//a[@class="content-type-list__link u-interface-link"]') %>%
        xml_attr('href') %>%
        str_extract('10.*')
    return(dois)
}

scrape_springer = function(this_url) {
    ## Avoid attracting too much attention
    Sys.sleep(.5)
    response = read_html(this_url)
    dois = parse_dois(response)
    
    ## It's not clear how many results per page, so always check for "next page"
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

## ~450 sec
message('Scraping Springer book chapters.  Takes ~10 minutes.')
tic()
springer_df = book_series_df %>%
    pull(URL) %>%
    plyr::ldply(scrape_springer, .progress = 'text')
toc()

## Confirm no missing DOIs
springer_df %>% 
    pull(ch_doi) %>% 
    negate(is.na)() %>% 
    any() %>% 
    assert_that(msg = 'Springer chapters with missing DOIs')
    

## Confirm we have results for all books in book_series_df
springer_df %>%
    mutate(first_page_url = str_extract(book_url, '[^?]*')) %>% 
    anti_join(book_series_df, by = c('first_page_url' = 'URL')) %>% 
    nrow() %>% 
    identical(0L) %>% 
    assert_that(msg = 'Some Springer chapters not scraped')

## Confirm we don't have any weird clusters of lengths suggesting cutoffs
# springer_df %>% 
#     mutate(first_page_url = str_extract(book_url, '[^?]*')) %>%
#     count(first_page_url) %>%
#     # ggplot(aes(first_page_url, n)) + geom_point()
#     ggplot(aes(n)) + geom_bar()

## Retrieve chapter metadata from CrossRef ----------
## Takes ~43 seconds / 100 DOIs
## So ~40 minutes for all ~5.5k
tic()
cr_df = cr_works(springer_df$ch_doi, .progress = 'text')
toc()

springer_books_df = cr_df %>%
    pluck('data') %>% 
    ## Join w/ ch-level DOIs, so we can see what DOIs weren't in CR
    right_join(springer_df, by = c('doi' = 'ch_doi')) %>%
    mutate(book_url = str_extract(book_url, '^[^\\?]+')) %>% 
    ## And join w/ the original DF to track book series
    left_join(select(book_series_df, 
                     URL, publication_group, publication_series), 
              by = c('book_url' = 'URL'))

springer_books_df %>% 
    filter(is.na(publication_series)) %>% 
    nrow() %>% 
    identical(0L) %>% 
    assert_that(msg = 'NA values in publication_series')

## Save results ----------
write_rds(springer_books_df, 
          file.path(data_folder, '02_springer_books.rds'))

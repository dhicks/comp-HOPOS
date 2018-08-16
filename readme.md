This repository contains the complete scripts and data files used to construct the Computational History of Philosophy of Science (Comp HOPOS) dataset.  This readme file contains information on reproducing the dataset (and modifying the scripts for other purposes); a license statement; a brief overview of the method by which the dataset is constructed; and an overview of the files included in the repository.  

The dataset can be downloaded at <link>.  The downloads include a data dictionary.  A paper describing the motivations and construction method in more detail is available at <link>.  

These scripts were developed by Daniel J. Hicks, Rick Morris, and Evelyn Brister.  The repository is maintained by Daniel J. Hicks.  To report errors or other issues, please use the issue tracker for this repository (preferred) or email <hicks.daniel.j@gmail.com>.  


# Reproducibility #

In principle, the dataset can be reproduced by running the scripts (the `R` files) in numerical order.  There are, of course, a number of further details and complications.  

- With the exception of the gender attribution websites accessed in `06_gender.R`, all of the software tools and data are free (or free for non-commercial use).  
- The `R` files are run using the [R programming language](https://cran.r-project.org/).  
- `04_dedupe_names.R` is essentially a wrapper around a separate (included) Python script.  This script requires [Python 3](https://www.python.org/downloads/).  The R script needs to be configured to call the correct Python installation.  
- The following input files are required: 
    1. `00_Boston.csv` and `00_Western_Ontario.csv`, which record volume-level information for the Boston and Western Ontario book series, respectively.  These files can be generated by conducting [a search on SpringerLink](https://link.springer.com/search?facet-series=%225710%22&facet-content-type=%22Book%22&showAll=true) and then clicking on the downward-arrow button in the upper-right.  
    2. `00_Minnesota.xlsx`, which records chapter-level information for the Minnesota book series.  This file was created by Evelyn Brister with assistance from Aaron Crespo.  
    3. `01_canonical_titles.csv`, which includes canonical names for journals.  This file can also be constructed manually from the output file `01_journal_data.csv`. 

- Every script has a number of dependencies, and the dependencies vary from script to script.  In particular, note the following: 
    - Unless otherwise noted, all dependencies should be available using standard package managers (e.g., R's built-in package manager, `pip` or Anaconda for Python).  
    - The Python dependencies used in `04_dupe_remove.py` are unique to that script.  
    - `06_gender.R` accesses files [in another repository](https://github.com/cblevins/Gender-ID-By-Time). 
    - `06_gender.R` also accesses APIs for two subscription services, [NamSor](http://www.namsor.com/) and [genderize.io](https://genderize.io/).  After subscribing to those services, create a file `api_keys.R` in the working directory, and add API keys with the following format:  
    ```
    namsor_key = 'stringofcharacters'
    namsor_user = 'namsor.com/e@mail.com/12345'
    genderize.io_key = 'otherstringofcharacters'
    ```

- The two scripts that retrieve larges amounts of data, `01_journals.R` and `02_springer_books.R`, have relatively long runtimes, approximately 20 and 45 minutes respectively.  

- Because of these two last points, it is recommended that each script be run individually.  While the entire process could be automated once all of the dependencies are satisfied, this will not be necessary in many cases (because the dataset has already been constructed).  

- Note on the CrossRef API from the RCRossRef documentation:  

> Be nice and share your email with Crossref
> The Crossref team encourage requests with appropriate contact information and will forward you to a dedicated API cluster for improved performance when you share your email address with them. <https://github.com/CrossRef/rest-api-doc#good-manners--more-reliable-service>
> To pass your email address to Crossref via this client, simply store it as environment variable in
.Renviron like this:
> 1. Open file: file.edit("~/.Renviron")
> 2. Add email address to be shared with Crossref crossref_email = name@example.com
> 3. Save the file and restart your R session
> Don’t wanna share your email any longer? Simply delete it from ~/.Renviron




# Dataset Construction #

The primary source of data for the Comp HOPOS dataset is [CrossRef](https://en.wikipedia.org/wiki/Crossref), which maintains registration records for [the (vast) majority of digital object identifiers (DOIs)](https://github.com/greenelab/crossref/issues/3).  Recently, many scholarly publishers have been "minting" DOIs for their archives; combined with [an elegant R API](https://duckduckgo.com/?q=rcrossref&atb=v17&ia=web), this makes it possible to easily and rapidly retrieve a complete set of metadata records for many scholarly journals.  

Two other sources of data are incorporated into the Comp HOPOS dataset.  Chapter-level DOIs for the Boston and Western Ontario book series are scraped from search results in Springer's public search engine.  CrossRef is then used to retrieve the metadata for a chapter in a standard format.  For the Minnesota book series, Evelyn Brister retrieved the data from the University of Minnesota website manually, with assistance from Aaron Crespo.  

After combining these data sources, author names are disambiguated.  Using canonical names, philosophers of science are identified and genders are attributed to philosophers of science based on author names.  

Currently, philosophers of science are identified as authors who (after name disambiguation) have 2 or more articles in an identified set of "primary philosophy of science" journals (including the three book series).  


# Files Overview #

- `00_Boston.csv`: Volume-level information for Boston book series
- `00_Minnesota.xlsx`: Chapter-level information for the Minnesota book series
- `00_Western_Ontario.csv`: Volume-level information for the Western Ontario book series
- `01_canonical_titles.csv`: Canonical titles for journals
- `01_journals.R`: Retrieve metadata for journal articles using CrossRef API
- `02_springer_books.R`: Retrieve metadata for Springer-published book chapters using Springer website + CrossRef API
- `03_combine.R`: Combine data retrieved in previous two scripts
- `04_dedupe_names.R`: R wrapper around `04_dupe_remove.py`
- `04_dupe_remove.py`: Primary Python script used for author name disambiguation
- `04_qc_file_diffs.py`: Auxiliary Python script used for author name disambiguation
- `04_readme.txt`: Readme for Python scripts
- `05_verify_samples.R`: Generates subsets of author disambiguation output files for manual review
- `06_gender.R`:  Identifies philosophers of science in the dataset and attributes gender based on author name
- `07_dataset.R	`:  Combines metadataset with gender attribution into dataset suitable for public distribution
- `readme.md`:  This readme


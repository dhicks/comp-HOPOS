DATA := ../data
PYTHON := ~/opt/anaconda3/bin/python

all: last

last: $(DATA)/07_unf.csv

$(DATA)/07_*.* &: 07_dataset.R \
                  $(DATA)/03_authors.rds \
                  $(DATA)/04_names_verif.csv \
                  $(DATA)/06_phil_sci.Rds \
                  $(DATA)/06_gender.Rds \
                  $(DATA)/00_drop.Rds \
                  $(DATA)/00_drop_authors.Rds \
                  $(DATA)/00_name_change.Rds \
                  $(DATA)/00_fix_gender.Rds
	Rscript 07_dataset.R

$(DATA)/06_*.* &: 06_gender.R \
                  $(DATA)/03_authors.rds \
                  $(DATA)/04_names_verif.csv
	Rscript 06_gender.R

## 05 is used to generate samples of deduped names for manual checks
$(DATA)/05_*.* &: 05_verify_samples.R \
                  $(DATA)/04_names_verif.csv
	Rscript 04_verify_samples.R

$(DATA)/04_*.* &: 04_dupe_remove.py \
                  $(DATA)/03_names.csv
	$(PYTHON) 04_dupe_remove.py $(DATA)/03_names.csv $(DATA)/04_names

#$(DATA)/04_*.* &: 04_dedupe_names.R \
#                  04_dupe_remove.py
#                  03_names.csv
#	Rscript 04_dedupe_names.R

$(DATA)/03_*.* &: 03_combine.R \
                  $(DATA)/01_papers.rds \
                  $(DATA)/02_springer_books.rds \
                  $(DATA)/00_Minnesota.xlsx \
                  $(DATA)/00_canonical_titles.csv
	Rscript 03_combine.R

$(DATA)/02_springer_books.rds : 02_springer_books.R \
                                $(DATA)/00_Boston.csv \
                                $(DATA)/00_Western_Ontario.csv
	Rscript 02_springer_books.R

$(DATA)/01_*.* &: 01_journals.R
	Rscript 01_journals.R

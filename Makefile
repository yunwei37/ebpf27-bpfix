# Paper compilation and arXiv packaging Makefile

MAIN = main
ARXIV_DIR = arxiv-submission
ARXIV_TAR = arxiv-submission.tar.gz
DOCKER_IMAGE ?= texlive/texlive:TL2025-historic
DOCKER_UID := $(shell id -u)
DOCKER_GID := $(shell id -g)
DOCKER_RUN = docker run --rm -v $(CURDIR):/workdir -w /workdir $(DOCKER_IMAGE)
PDFLATEX = pdflatex -interaction=nonstopmode -halt-on-error
BIBTEX = bibtex
TEX_BUILD_CMD = $(PDFLATEX) $(MAIN).tex && $(BIBTEX) $(MAIN) && $(PDFLATEX) $(MAIN).tex && $(PDFLATEX) $(MAIN).tex
ARXIV_CHECK_CMD = $(PDFLATEX) $(MAIN).tex && $(PDFLATEX) $(MAIN).tex

# All section files
SECTIONS = $(wildcard sections/*.tex)
FIGURES = $(wildcard figures/*.tex figures/*.pdf)
PDF_FIGURES = $(wildcard figures/*.pdf)
TABLES = $(wildcard tables/*.tex)
HELPERS = $(wildcard helpers/*.tex)

.PHONY: pdf docker arxiv arxiv-pack arxiv-check clean cleanall watch help docker-arxiv

# Build PDF with latexmk
pdf: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex $(SECTIONS) $(FIGURES) $(TABLES) $(HELPERS) reference.bib
	latexmk -pdf -interaction=nonstopmode $(MAIN).tex

# Watch for changes and rebuild
watch:
	latexmk -pdf -pvc -interaction=nonstopmode $(MAIN).tex

# Generate arXiv submission package
arxiv: $(MAIN).pdf arxiv-pack

arxiv-pack:
	@test -s $(MAIN).bbl || { echo "Missing $(MAIN).bbl; run latexmk/BibTeX first."; exit 1; }
	@echo "Creating arXiv submission package..."
	rm -rf $(ARXIV_DIR) $(ARXIV_TAR)
	mkdir -p $(ARXIV_DIR)/figures

	# Expand all \input commands into a single file
	latexpand --empty-comments $(MAIN).tex > $(ARXIV_DIR)/$(MAIN).tex
	@if grep -Eq '\\input\{(helpers|sections|figures|tables)/' $(ARXIV_DIR)/$(MAIN).tex; then \
		echo "arXiv main.tex still contains project-local \\input paths"; \
		exit 1; \
	fi

	# Copy bibliography output (bbl, not bib)
	cp $(MAIN).bbl $(ARXIV_DIR)/

	# Copy PDF assets and local ACM files used by the paper.
	cp $(PDF_FIGURES) $(ARXIV_DIR)/figures/
	cp resource/acmart.cls resource/ACM-Reference-Format.bst $(ARXIV_DIR)/

	# Create tarball
	tar -czf $(ARXIV_TAR) -C $(ARXIV_DIR) .

	@echo ""
	@echo "arXiv submission package created: $(ARXIV_TAR)"
	@echo "Contents:"
	@tar -tzf $(ARXIV_TAR)

# Validate the arXiv package by compiling only the packaged files.
arxiv-check: $(ARXIV_TAR)
	@echo "Validating arXiv submission package..."
	@tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	tar -xzf $(ARXIV_TAR) -C "$$tmp"; \
	(cd "$$tmp" && $(ARXIV_CHECK_CMD)) >/dev/null; \
	test -s "$$tmp/$(MAIN).pdf"; \
	if grep -Eq 'Citation .* undefined|Reference .* undefined|There were undefined (references|citations)|LaTeX Error|Fatal error' "$$tmp/$(MAIN).log"; then \
		echo "arXiv package validation found LaTeX citation/reference errors"; \
		exit 1; \
	fi
	@echo "arXiv package validation passed."

# Clean intermediate files
clean:
	latexmk -c
	rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.synctex.gz *.bbl *.blg

# Clean everything including PDF and arxiv package
cleanall: clean
	latexmk -C
	rm -rf $(ARXIV_DIR) $(ARXIV_TAR)
	rm -f $(MAIN).pdf

# Build PDF using Docker (more reliable)
docker:
	$(DOCKER_RUN) /bin/sh -c 'set -e; trap "chown -R $(DOCKER_UID):$(DOCKER_GID) $(MAIN).* 2>/dev/null || true" EXIT; if ! ($(TEX_BUILD_CMD)) >/tmp/$(MAIN)-build.log 2>&1; then cat /tmp/$(MAIN)-build.log; exit 1; fi'

# Build arXiv package using Docker
docker-arxiv:
	$(DOCKER_RUN) /bin/sh -c 'set -e; trap "chown -R $(DOCKER_UID):$(DOCKER_GID) $(MAIN).* $(ARXIV_DIR) $(ARXIV_TAR) 2>/dev/null || true" EXIT; rm -f $(MAIN).aux $(MAIN).bbl $(MAIN).blg $(MAIN).fdb_latexmk $(MAIN).fls $(MAIN).log $(MAIN).out $(MAIN).pdf; if ! ($(TEX_BUILD_CMD)) >/tmp/$(MAIN)-build.log 2>&1; then cat /tmp/$(MAIN)-build.log; exit 1; fi; make arxiv-pack arxiv-check'

# Word count
wc:
	texcount -inc -sum $(MAIN).tex

# Help
help:
	@echo "Paper Makefile targets:"
	@echo "  pdf        - Build PDF using local latexmk"
	@echo "  docker     - Build PDF using Docker (texlive/texlive)"
	@echo "  watch      - Watch for changes and rebuild"
	@echo "  arxiv      - Create arXiv submission package"
	@echo "  arxiv-pack - Create arXiv package from existing PDF/BBL outputs"
	@echo "  arxiv-check - Validate arXiv package by compiling only packaged files"
	@echo "  docker-arxiv - Create and validate arXiv package using Docker"
	@echo "  clean      - Remove intermediate files"
	@echo "  cleanall   - Remove all generated files"
	@echo "  wc         - Word count"

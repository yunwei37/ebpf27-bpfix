# Paper compilation and arXiv packaging Makefile

MAIN = main
ARXIV_DIR = arxiv-submission
ARXIV_TAR = arxiv-submission.tar.gz
DOCKER_IMAGE = texlive/texlive:latest

# All section files
SECTIONS = $(wildcard sections/*.tex)
FIGURES = $(wildcard figures/*.tex figures/*.pdf)
TABLES = $(wildcard tables/*.tex)
HELPERS = $(wildcard helpers/*.tex)

.PHONY: pdf docker arxiv clean cleanall watch help

# Build PDF with latexmk
pdf: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex $(SECTIONS) $(FIGURES) $(TABLES) $(HELPERS) reference.bib
	latexmk -pdf -interaction=nonstopmode $(MAIN).tex

# Watch for changes and rebuild
watch:
	latexmk -pdf -pvc -interaction=nonstopmode $(MAIN).tex

# Generate arXiv submission package
arxiv: $(MAIN).pdf $(MAIN).bbl
	@echo "Creating arXiv submission package..."
	rm -rf $(ARXIV_DIR)
	mkdir -p $(ARXIV_DIR)

	# Expand all \input commands into a single file
	latexpand --empty-comments $(MAIN).tex > $(ARXIV_DIR)/$(MAIN).tex

	# Copy bibliography (bbl, not bib)
	cp $(MAIN).bbl $(ARXIV_DIR)/

	# Copy all PDF figures
	mkdir -p $(ARXIV_DIR)/figures
	cp figures/*.pdf $(ARXIV_DIR)/figures/ 2>/dev/null || true

	# Copy ACM class file if present
	cp acmart.cls $(ARXIV_DIR)/ 2>/dev/null || true
	cp ACM-Reference-Format.bst $(ARXIV_DIR)/ 2>/dev/null || true

	# Remove \bibliography command and add \input for bbl
	sed -i 's/\\bibliography{reference}/\\input{$(MAIN).bbl}/' $(ARXIV_DIR)/$(MAIN).tex

	# Create tarball
	tar -czvf $(ARXIV_TAR) -C $(ARXIV_DIR) .

	@echo ""
	@echo "arXiv submission package created: $(ARXIV_TAR)"
	@echo "Contents:"
	@tar -tzvf $(ARXIV_TAR)

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
	docker run --rm -v $(PWD):/workdir -w /workdir $(DOCKER_IMAGE) \
		latexmk -pdf -interaction=nonstopmode $(MAIN).tex

# Build arXiv package using Docker
docker-arxiv:
	docker run --rm -v $(PWD):/workdir -w /workdir $(DOCKER_IMAGE) \
		make arxiv

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
	@echo "  docker-arxiv - Create arXiv package using Docker"
	@echo "  clean      - Remove intermediate files"
	@echo "  cleanall   - Remove all generated files"
	@echo "  wc         - Word count"

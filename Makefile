.PHONY: main clean-cache preview all clean normalize summary
SED := $(shell command -v gsed 2> /dev/null || echo sed)

all: main clean-cache preview normalize summary

main:
	bundle exec ruby ./main.rb

clean-cache:
	@echo "Cleaning cache and progress data..."
	@rm -rf cache
	@rm -f links_data.json

preview:
	bundle exec ruby ./main.rb fluxcd.io deploy-preview-1573--fluxcd.netlify.app preview-report.csv false

run_with_preview: preview-report.csv

preview-report.csv:
	@echo "Running with preview URL: $(PREVIEW_URL)"
	bundle exec ruby ./main.rb $(PRODUCTION_URL) $(PREVIEW_URL) preview-report.csv false

clean: clean-cache
	@rm -f report.csv preview-report.csv pr-summary.csv baseline-unresolved.csv
	@echo "Clean complete!"

normalize: report.csv preview-report.csv
	@# Normalize the main report.csv
	@$(SED) -i '1d' report.csv
	@PRODUCTION_DOMAIN=$(shell if [ -z "$(PRODUCTION_URL)" ]; then echo "fluxcd.io"; else echo "$(PREVIEW_URL)"; fi) ;\
		PREVIEW_DOMAIN=$(shell if [ -z "$(PREVIEW_URL)" ]; then echo "deploy-preview-1573--fluxcd.netlify.app"; else echo "$(PREVIEW_URL)"; fi) ;\
		$(SED) -i "s/$$PRODUCTION_DOMAIN/$$PREVIEW_DOMAIN/1; s/$$PRODUCTION_DOMAIN/$$PREVIEW_DOMAIN/1" report.csv
	@sort -o report.csv report.csv
	
	@# Normalize the preview-report.csv
	@$(SED) -i '1d' preview-report.csv
	@sort -o preview-report.csv preview-report.csv

summary:
	bundle exec ruby ./lib/summary.rb

check-summary:
	./scripts/check_summary.sh

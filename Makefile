.PHONY: main clean-cache preview all clean normalize summary
all: main clean-cache preview normalize summary

main:
	ruby ./main.rb

clean-cache:
	@echo "Cleaning cache and progress data..."
	@rm -rf cache
	@rm -f links_data.json

preview:
	ruby ./main.rb fluxcd.io deploy-preview-1573--fluxcd.netlify.app preview-report.csv false

run_with_preview:
	@echo "Running with preview URL: $(PREVIEW_URL)"
	ruby ./main.rb fluxcd.io $(PREVIEW_URL) preview-report.csv false

clean: clean-cache
	@rm -f report.csv preview-report.csv pr-summary.csv baseline-unresolved.csv
	@echo "Clean complete!"

normalize:
	@# Normalize the main report.csv
	@gsed -i '1d' report.csv
	@PREVIEW_DOMAIN=$(if [ -z "$(PREVIEW_URL)" ]; then echo "deploy-preview-1573--fluxcd.netlify.app"; else echo "$(PREVIEW_URL)"; fi)
	@gsed -i "s/fluxcd.io/$$PREVIEW_DOMAIN/1; s/fluxcd.io/$$PREVIEW_DOMAIN/1" report.csv
	@sort -o report.csv report.csv
	
	@# Normalize the preview-report.csv
	@gsed -i '1d' preview-report.csv
	@sort -o preview-report.csv preview-report.csv

summary:
	ruby ./lib/summary.rb

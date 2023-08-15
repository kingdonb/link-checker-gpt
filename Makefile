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

clean: clean-cache
	@rm -f report.csv preview-report.csv
	@echo "Clean complete!"

normalize:
	@# Normalize the main report.csv
	@gsed -i '1d' report.csv
	@awk 'NR==1{print $0; next} {print $0 | "sort"}' report.csv > tmp.csv && mv tmp.csv report.csv
	@gsed -i 's/fluxcd.io/deploy-preview-1573--fluxcd.netlify.app/1; s/fluxcd.io/deploy-preview-1573--fluxcd.netlify.app/1' report.csv
	
	@# Normalize the preview-report.csv
	@gsed -i '1d' preview-report.csv
	@awk 'NR==1{print $0; next} {print $0 | "sort"}' preview-report.csv > tmp.csv && mv tmp.csv preview-report.csv

summary:
	ruby ./lib/summary.rb

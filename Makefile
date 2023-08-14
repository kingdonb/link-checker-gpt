.PHONY: main clean-cache preview all clean
all: main clean-cache preview

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

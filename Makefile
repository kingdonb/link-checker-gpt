.PHONY: all clean
all:
	ruby ./link_checker.rb

clean:
	@echo "Cleaning cache and progress data..."
	@rm -rf cache
	@rm -f links_data.json
	@rm -f report.csv
	@echo "Clean complete!"

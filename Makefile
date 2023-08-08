
clean:
	@echo "Cleaning cache and progress data..."
	@rm -rf cache
	@rm -f progress_data.dump
	@rm report.csv
	@echo "Clean complete!"

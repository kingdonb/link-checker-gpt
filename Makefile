
clean:
	@echo "Cleaning cache and progress data..."
	@rm -rf cache
	@rm -f progress_data.dump
	@rm -f report.csv
	@echo "Clean complete!"

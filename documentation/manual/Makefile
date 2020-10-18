all:
	sed 's/^# /\\newpage\n# /g' manual.md  > manual2.md
	pandoc --metadata-file=custom.yaml --toc -V documentclass=report  --from=markdown+multiline_tables -H custom.tex manual2.md -o manual.pdf
	rm manual2.md
	mv manual.pdf ..

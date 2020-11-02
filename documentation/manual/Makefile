all:
	sed 's/^# /\\newpage\n# /g' manual.md  > manual2.md
	sed 's/^# /\\newpage\n# /g' techreport.md  > techreport2.md
	#pandoc --metadata-file=custom.yaml --toc --top-level-division=part -V documentclass=report  --from=markdown+multiline_tables -H custom.tex manual2.md -o manual.pdf
	pandoc --metadata-file=custom.yaml --toc -V documentclass=report  --from=markdown+multiline_tables -H custom.tex manual2.md -o manual.pdf
	pandoc --metadata-file=custom.yaml --toc -V documentclass=report  --from=markdown+multiline_tables -H custom.tex techreport2.md -o techreport.pdf
	rm manual2.md
	mv manual.pdf ../ozmoo_5.pdf
	mv techreport.pdf ../techdocs/techreport_5.pdf

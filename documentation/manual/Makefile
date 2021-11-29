all:
	sed 's/^# /\\newpage\n# /g' manual.md  > manual2.md
	sed 's/^# /\\newpage\n# /g' techreport.md  > techreport2.md
	#pandoc --metadata-file=custom.yaml --toc --top-level-division=part -V documentclass=report  --from=markdown+multiline_tables -H custom.tex manual2.md -o manual.pdf
	pandoc --metadata-file=custom.yaml --toc -V documentclass=report  --from=markdown+multiline_tables -H custom.tex manual2.md -o manual.pdf
	pandoc --metadata-file=custom.yaml --toc -V documentclass=report  --from=markdown+multiline_tables -H custom.tex techreport2.md -o techreport.pdf
	pandoc --metadata-file=custom-player.yaml --from=markdown+multiline_tables -H custom.tex player_manual.md -o player_manual.pdf
	rm manual2.md
	rm techreport2.md
	mv manual.pdf ../ozmoo_9.pdf
	mv techreport.pdf ../techreport_9.pdf
	mv player_manual.pdf ../player_manual_9.pdf

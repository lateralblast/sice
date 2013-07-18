suit
====

Sun Update ILOM Tool

A tool written in Perl that uses the Expect module to automate ILOM configuration and firmware updates.

Usage
=====

	./suit.pl -m model -i hostname -p password -[n,e,f,g]

	-n Change Default password
	-e Enable custom settings
	-g Check firmware version
	-f Update firmware if required
	-a Perform all steps
	-t Run in test mode (don't do firmware update)
	-F Print firmware information
	-d Specify default delay [10 sec]



![alt tag](https://raw.githubusercontent.com/lateralblast/sice/master/sice.jpg)

> n.  1.  The number six at dice.
> ---<cite> Webster's Revised Unabridged Dictionary, published 1913 by C. & G. Merriam Co. </cite>

SICE
====

Sun ILOM Configure Environment

Introduction
------------

A tool written in Perl that uses the Expect module to automate ILOM configuration and firmware updates.

License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Usage
-----

```
$ sice.pl -m model -i hostname -p password -[n,e,f,g]

	-n:	Change Default password
	-e:	Enable custom settings
	-g:	Check firmware version
	-f:	Update firmware if required
	-a:	Perform all steps
	-t:	Run in test mode (don't do firmware update)
	-F:	Print firmware information
	-d:	Specify default delay [10 sec]
```

Examples
--------

Check firmware version:

```
$ sice.pl -i 192.168.1.230 -p changeme -g
Password:
Waiting for daemons to initialize...
Daemons ready

Oracle(R) Integrated Lights Out Manager

Version 3.0.12.4.zb r83058

Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved.

Warning: password is set to factory default.

->
-> version
SP firmware 3.0.12.4.zb
SP firmware build number: 83058
SP firmware date: Fri Aug  9 19:28:50 PDT 2013
SP filesystem version: 0.1.22

-> show /SYS product_name

  /SYS
    Properties:
        product_name = SPARC-Enterprise-T5120

Hardware found: T5120

-> version
SP firmware 3.0.12.4.zb
SP firmware build number: 83058
SP firmware date: Fri Aug  9 19:28:50 PDT 2013
SP filesystem version: 0.1.22

-> show /HOST sysfw_version

  /HOST
    Properties:
        sysfw_version = Sun System Firmware 7.4.6.c 2013/08/09 20:48

Firmware is up to date
```

Requirements
------------

The following Perl modules are required:

- Expect
- Getopt::Std
- Net::FTP
- File::Slurp
- File::Basename
- Net::TFTPd
- Socket
- Sys::Hostname

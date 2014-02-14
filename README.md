convert.rb
==========

**convert.rb** is a script that interactively prompts you for ISBN numbers,
uses the Amazon Product Advertising API to look up information about the
book. It then stores this information in the file ```dokuwiki.txt```, in a
format that is valid [DokuWiki table row syntax][dw].

The software lends itself to use in conjunction with a barcode scanner to
rapidly record a large number of books.

This software was written to maintain the [libary records of the
*Abteilung-für-Redundanz-Abteilung*][bibliothek], a hackspace in Berlin.

Setup
-----
An [Amazon Web Services][aws] developer account that is signed up for the
[Amazon Product Advertising API][apaa] is required. You must enter your
Access Key ID	and Secret Access Key in the file ```config.rb```, otherwise
the script will not work.

Library Input
-------------
When the file ```dokuwiki.txt``` is not empty at program start, it is being
used to initialize the list of known ISBNs. **convert.rb** will then append
the rows created in this session to the file. 

Features
--------
* Prevents duplicates based on ISBN
* Supports multiple Amazon locales and tries them in order until valid data
  is found
* Use ```convert.rb --help``` for a list of command-line options

Disclaimer
----------
This software has not been excessively tested. You should check the contents
of ```dokuwiki.txt``` for obvious errors before using it as input for
DokuWiki.

Before using this software with your AWS credentials, you should carefully
read the relevant Amazon Terms of Service and consider whether your intended
use is covered by them (Hint: It may be not).

[dw]: https://www.dokuwiki.org/wiki:syntax#tables
[bibliothek]: https://afra-berlin.de/dokuwiki/doku.php?id=bibliothek
[aws]: https://aws.amazon.com
[apaa]: https://affiliate-program.amazon.com/gp/advertising/api/detail/main.html
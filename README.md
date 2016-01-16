# Archive::SimpleZip

Perl6 module to write Zip archives.

## Synopsis


```

use Archive::Zip

my $obj = Archive::Zip.new("mine.zip")

$obj.add("somefile.txt");

```

## Description

## Installation

Assuming you have a working perl6 installation you should be able to
install this with *ufo* :

    ufo
    make test
    make install

*ufo* can be installed with *panda* for rakudo:

    panda install ufo

Or you can install directly with "panda":

    # From the source directory
   
    panda install .

    # Remote installation

    panda install Archive::SimpleZip

Other install mechanisms may be become available in the future.

## Support

This should be considered experimental software until such time that
Perl 6 reaches an official release.  However suggestions/patches are
welcomed via github at

   https://github.com/pmws/Archive-SimpleZip

## Licence

Please see the LICENCE file in the distribution

(C) Paul Marquess 2016


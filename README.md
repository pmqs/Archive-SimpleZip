# Archive::SimpleZip

Perl6 module to write Zip archives.

## Synopsis


```

use Archive::SimpleZip;

# Create a zip file in filesystem
my $obj = SimpleZip.new("mine.zip");

# Create a zip file in memory
my $blob = Blob.new();
my $obj2 = SimpleZip.new($blob);

# Add a file to the zip archive
$obj.add("somefile.txt".IO);

# Add a Blob/String
$obj.add("payload data here", :name<data1>);

$obj.close();
```


## Description

Simple write-only interface from creation of Zip files.

This is a proof of concept. The interface will change.


## Support

This should be considered experimental software until such time that
Perl 6 reaches an official release.  However suggestions/patches are
welcomed via github at

   https://github.com/pmqs/Archive-SimpleZip

## Licence

Please see the LICENCE file in the distribution

(C) Paul Marquess 2016


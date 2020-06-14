# Archive::SimpleZip

Raku (Perl6) module to write Zip archives.

![.github/workflows/test.yml](https://github.com/pmqs/Archive-SimpleZip/workflows/.github/workflows/test.yml/badge.svg)
[![Build Status](https://travis-ci.com/pmqs/Archive-SimpleZip.svg?branch=master)](https://travis-ci.com/pmqs/Archive-SimpleZip)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/pmqs/Archive-SimpleZip?svg=true)](https://ci.appveyor.com/project/pmqs/Archive-SimpleZip/branch/master)



## Synopsis


```

use Archive::SimpleZip;

# Create a zip file in filesystem
my $obj = SimpleZip.new("mine.zip");

# Add a file to the zip archive
$obj.add("somefile.txt".IO);

# Add a Blob/String
$obj.add("payload data here", :name<data1>);
$obj.add(Blob.new([2,4,6]), :name<data2>);

# Drop a filehandle into the zip archive
my $handle = "some file".IO.open;
$obj.add($handle, :name<data3>);

use IO::Glob;
$zip.add(glob("*.c"));

$obj.close();
```


## Description

Simple write-only interface to allow creation of Zip files.

Please note - this is module is a prototype. The interface will change.

## Support

Suggestions/patches are welcomed via github at

   https://github.com/pmqs/Archive-SimpleZip

## Licence

Please see the LICENCE file in the distribution

(C) Paul Marquess 2016-2020

# Semaphore Readers Writers Pattern or Light switch

[![Build Status](https://travis-ci.org/MARTIMM/mongo-perl6-driver.svg?branch=master)](https://travis-ci.org/MARTIMM/semaphore-readerswriters)
## Synopsis

```
use Semaphore::ReadersWriters;

my Semaphore::ReadersWriters $rw .= new;
$rw.add-mutex-names('shv');
my $shared-var = 10;

# After creating threads ...
# Some writer thread
$rw.writer( 'shv', {$shared-var += 2});

# Some reader thread
say 'Shared var is ', $rw.reader( 'shv', {$shared-var;});
```

## NOTE

## CHANGELOG

See [semantic versioning](http://semver.org/). Please note point 4. on that page: *Major version zero (0.y.z) is for initial development. Anything may change at any time. The public API should not be considered stable.*

* 0.1.0 First tests
* 0.0.1 Setup

## LICENSE

Released under [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0).

## AUTHORS

```
Marcel Timmerman
```
## CONTACT

MARTIMM on github: MARTIMM/mongo-perl6-driver

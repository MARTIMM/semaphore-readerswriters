use v6.c;
use Test;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
subtest {
  my Semaphore::ReadersWriters $rw .= new;
  my $shared-var = 10;

  isa-ok $rw, 'Semaphore::ReadersWriters';

  $rw.add-mutex-names(<shv def>);
  cmp-ok 'shv', '~~', any($rw.get-mutex-names), 'shv key set';
  cmp-ok 'def', '~~', any($rw.get-mutex-names), 'def key set';

  $rw.rm-mutex-names('def');
  cmp-ok 'def', '!~~', any($rw.get-mutex-names), 'def key removed';


  $rw.writer( 'def', {$shared-var += 2});
  CATCH {

    when X::AdHoc {
      cmp-ok .message,
      '~~',
      /:s mutex name \'def\' does not exist/,
      .message;
    }
  }

}, 'basic tests';

#-------------------------------------------------------------------------------
subtest {
  my Semaphore::ReadersWriters $rw .= new;
  $rw.add-mutex-names('shv');
  my $shared-var = 10;

  my @p;
  for ^10 {
    my $i = $_;

    @p.push: Promise.start( {
        diag "Try reading $i";
        $rw.reader( 'shv', { sleep((rand * 2).Int); $shared-var;});
      }
    );
  }

  pass "Result {.result}" for @p;
  pass "All reader threads have ended, no hangups";

}, 'only readers';

#-------------------------------------------------------------------------------
subtest {
  my Semaphore::ReadersWriters $rw .= new;
  $rw.add-mutex-names('shv');
  my $shared-var = 10;

  my @p;
  for ^10 {
    my $i = $_;

    @p.push: Promise.start( {
        diag "Try writing $i";
        $rw.writer( 'shv', { sleep((rand * 2).Int); ++$shared-var;});
      }
    );
  }

  pass "Result {.result}" for @p;
  pass "All writers threads have ended, no hangups";

}, 'only writers';

#-------------------------------------------------------------------------------
subtest {
  my Semaphore::ReadersWriters $rw .= new;
  $rw.add-mutex-names('shv');
  my $shared-var = 10;

  my @p;
  for (^3).pick(10) {
    my $i = $_;

    @p.push: Promise.start( {

        my $r;

        # Only when $i <= 2 then thread becomes a writer.
        # All others become readers
        if $i <= 2 {
          diag "Try writing $i";
          $r = $rw.writer( 'shv', {$shared-var += $i});
          diag "Written $r";
        }

        else {
          diag "Try reading $i";
          $r = $rw.reader( 'shv', {$shared-var});
          diag "Read $r";
        }

        $r;
      }
    );
  }
  
  pass "Result {.result}" for @p;
  pass "All threads have ended, no hangups";

}, 'readers and writers';

#-------------------------------------------------------------------------------
done-testing;

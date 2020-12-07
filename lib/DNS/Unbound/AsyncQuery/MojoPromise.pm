package DNS::Unbound::AsyncQuery::MojoPromise;

use strict;
use warnings;

use parent (
    'DNS::Unbound::AsyncQuery',
    'Mojo::Promise',
);

use constant _DEFERRED_CR => undef;

*_then = \&Mojo::Promise::then;

*_finally = \&Mojo::Promise::finally;

1;

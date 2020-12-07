package DNS::Unbound::EventLoopBase;

use strict;
use warnings;

use parent 'DNS::Unbound';

my %INSTANCE_REFHOLDER;

sub resolve_async {
    my $self = shift;

    if ( $INSTANCE_REFHOLDER{$self} ) {
        $INSTANCE_REFHOLDER{$self}[1]++;
    }
    else {
        $INSTANCE_REFHOLDER{$self} = [ $self, 1 ];
    }

    my $self_str = "$self";
    my $refholder_ar = $INSTANCE_REFHOLDER{$self};

    return $self->SUPER::resolve_async(@_)->finally( sub {
        $refholder_ar->[1]--;

        if ($refholder_ar->[1] == 0) {
            delete $INSTANCE_REFHOLDER{$self_str};
        }
    } );
}

sub DESTROY {
    my ($self) = @_;

    delete $INSTANCE_REFHOLDER{$self};

    return $self->SUPER::DESTROY();
}

1;

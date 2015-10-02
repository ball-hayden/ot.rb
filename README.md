# ot.rb

[![Build Status](https://travis-ci.org/ball-hayden/ot.rb.svg)](https://travis-ci.org/ball-hayden/ot.rb)

This is a Ruby port of the <https://github.com/Operational-Transformation/ot.js>
Operational Transformation library.

At this time, only `TextOperation` has been ported.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ot'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ot

## Usage

### TextOperation

`retain(n)`

Skip over a given number of charaters

`insert(string)`

Insert a string at the current position

`delete(n)`

Delete a string at the current position

`noop?`

Tests whether this operation has no effect.

`to_a`

Converts operation into an array value.
Note that this replaces the `toJSON` method in ot.js

`self.from_a(ops)`

Converts an array into an operation and validates it.
Note that this replaces the `fromJSON` method in ot.js

`apply(str)`

Apply an operation to a string, returning a new string. Throws an error if
there's a mismatch between the input string and the operation.

`invert(str)`

Computes the inverse of an operation. The inverse of an operation is the
operation that reverts the effects of the operation, e.g. when you have an
operation 'insert("hello "); skip(6);' then the inverse is 'delete("hello ");
skip(6);'. The inverse should be used for implementing undo.

`compose(operation2)`

Compose merges two consecutive operations into one operation, that
preserves the changes of both. Or, in other words, for each input string S
and a pair of consecutive operations A and B,
apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.

`compose_with?(other)`

When you use ctrl-z to undo your latest changes, you expect the program not
to undo every single keystroke but to undo your last sentence you wrote at
a stretch or the deletion you did by holding the backspace key down. This
This can be implemented by composing operations on the undo stack. This
method can help decide whether two operations should be composed. It
returns true if the operations are consecutive insert operations or both
operations delete text at the same position. You may want to include other
factors like the time since the last change in your decision.

`compose_with_inverted?(other)`

Decides whether two operations should be composed with each other
if they were inverted, that is
`shouldBeComposedWith(a, b) = shouldBeComposedWithInverted(b^{-1}, a^{-1})`.

`transform(operation1, operation2)`

Transform takes two operations A and B that happened concurrently and
produces two operations A' and B' (in an array) such that
`apply(apply(S, A), B') = apply(apply(S, B), A')`. This function is the
heart of OT.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then,
run `rake rspec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/ball-hayden/ot.rb>.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

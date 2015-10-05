require 'spec_helper'
require 'helpers'

# Ported from https://github.com/Operational-Transformation/ot.js/blob/master/test/lib/test-text-operation.js

describe OT::TextOperation do
  subject(:o) { OT::TextOperation.new }
  let(:h) { Helpers.new }

  n = 500

  it 'should test lengths' do
    expect(o.base_length).to eq 0
    expect(o.target_length).to eq 0

    o.retain(5)

    expect(o.base_length).to eq 5
    expect(o.target_length).to eq 5

    o.insert('abc')

    expect(o.base_length).to eq 5
    expect(o.target_length).to eq 8

    o.retain(2)

    expect(o.base_length).to eq 7
    expect(o.target_length).to eq 10

    o.delete(2)

    expect(o.base_length).to eq 9
    expect(o.target_length).to eq 10
  end

  it 'should allow methods to be chained' do
    o.retain(5)
      .retain(0)
      .insert('lorem')
      .insert('')
      .delete('abc')
      .delete(3)
      .delete(0)
      .delete('')

    expect(o.ops.length).to eq 3
  end

  it 'should correctly apply an OT operation' do
    n.times do
      str = h.random_string(50)
      o = h.random_operation(str)

      expect(o.base_length).to eq str.length
      expect(o.target_length).to eq o.apply(str).length
    end
  end

  it 'should correctly invert an OT operation' do
    n.times do
      str = h.random_string(50)
      o = h.random_operation(str)
      p = o.invert(str)

      expect(p.target_length).to eq o.base_length
      expect(p.base_length).to eq o.target_length

      expect(str).to eq(p.apply(o.apply(str)))
    end
  end

  it 'should not do anything if an operation is empty' do
    o.retain(0)
    o.insert('')
    o.delete('')

    expect(o.ops.length).to eq 0
  end

  it 'should correctly identify equal transformations' do
    op1 = OT::TextOperation.new.delete(1).insert('lo').retain(2).retain(3)
    op2 = OT::TextOperation.new.delete(-1).insert('l').insert('o').retain(5)

    expect(op1).to eq op2

    op1.delete(1)
    op2.retain(1)

    expect(op1).to_not eq op2
  end

  it 'should correctly merge operations' do
    expect(o.ops.length).to eq 0

    o.retain(2)

    expect(o.ops.length).to eq 1
    expect(o.ops.last).to eq 2

    o.retain(3)

    expect(o.ops.length).to eq 1
    expect(o.ops.last).to eq 5

    o.insert('abc')

    expect(o.ops.length).to eq 2
    expect(o.ops.last).to eq 'abc'

    o.insert('xyz')

    expect(o.ops.length).to eq 2
    expect(o.ops.last).to eq 'abcxyz'

    o.delete('d')

    expect(o.ops.length).to eq 3
    expect(o.ops.last).to eq(-1)

    o.delete('d')

    expect(o.ops.length).to eq 3
    expect(o.ops.last).to eq(-2)
  end

  it 'should correctly identify when an operation has no effect' do
    expect(o).to be_noop

    o.retain(5)
    expect(o).to be_noop

    o.retain(3)
    expect(o).to be_noop

    o.insert('lorem')
    expect(o).to_not be_noop
  end

  it 'should generate a string representation of the transform' do
    o.retain(2)
    o.insert('lorem')
    o.delete('ipsum')
    o.retain(5)

    expect(o.to_s).to eq "retain 2, insert 'lorem', delete 5, retain 5"
  end

  it 'should correctly serialize and deserialize the transformation from an array' do
    n.times do
      doc = h.random_string(50)
      operation = h.random_operation(doc)

      expect(operation).to eq OT::TextOperation.from_a(operation.to_a)
    end
  end

  it 'should correctly handle errors in an input array' do
    ops = [2, -1, -1, 'cde']
    o = OT::TextOperation.from_a(ops)

    expect(o.ops.length).to eq 3
    expect(o.base_length).to eq 4
    expect(o.target_length).to eq 5

    ops2 = ops.dup
    ops2.push(insert: 'x')

    expect { OT::TextOperation.from_a(ops2) }.to raise_exception 'unknown operation: {:insert=>"x"}'

    ops3 = ops.dup
    ops3.push(nil)
    expect { OT::TextOperation.from_a(ops3) }.to raise_exception 'unknown operation: '
  end

  it 'should detect sequential operations that can be composed together for "natural" undo' do
    a = OT::TextOperation.new.retain(3)
    b = OT::TextOperation.new.retain(1).insert('tag').retain(2)

    expect(a.compose_with?(b)).to be true
    expect(b.compose_with?(a)).to be true

    a = OT::TextOperation.new.retain(1).insert('a').retain(2)
    b = OT::TextOperation.new.retain(2).insert('b').retain(2)
    expect(a.compose_with?(b)).to be true
    a.delete(3)
    expect(a.compose_with?(b)).to be false

    a = OT::TextOperation.new.retain(1).insert('b').retain(2)
    b = OT::TextOperation.new.retain(1).insert('a').retain(3)
    expect(a.compose_with?(b)).to be false

    a = OT::TextOperation.new.retain(4).delete(3).retain(10)
    b = OT::TextOperation.new.retain(2).delete(2).retain(10)
    expect(a.compose_with?(b)).to be true

    b = OT::TextOperation.new.retain(4).delete(7).retain(3)
    expect(a.compose_with?(b)).to be true

    b = OT::TextOperation.new.retain(2).delete(9).retain(3)
    expect(a.compose_with?(b)).to be false
  end

  it 'checks if two operations could be composed together if they were inverted' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)

      a_inv = a.invert(str)
      after_a = a.apply(str)

      b = h.random_operation(after_a)
      b_inv = b.invert(after_a)

      expect(b_inv.compose_with_inverted?(a_inv)).to eq a.compose_with?(b)
    end
  end

  it 'should compose operations' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)

      after_a = a.apply(str)
      expect(after_a.length).to eq a.target_length

      b = h.random_operation(after_a)
      after_b = b.apply(after_a)
      expect(after_b.length).to eq b.target_length

      ab = a.compose(b)
      # expect(a.meta).to eq ab.meta
      expect(b.target_length).to eq ab.target_length

      after_ab = ab.apply(str)
      expect(after_ab).to eq after_b
    end
  end

  it 'should be able to transform operations' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)
      b = h.random_operation(str)

      primes = OT::TextOperation.transform(a, b)
      a_prime = primes[0]
      b_prime = primes[1]

      ab_prime = a.compose(b_prime)
      ba_prime = b.compose(a_prime)

      expect(ab_prime).to eq ba_prime

      after_ab_prime = ab_prime.apply(str)
      after_ba_prime = ba_prime.apply(str)

      expect(after_ab_prime).to eq after_ba_prime
    end
  end
end

require 'spec_helper'
require 'helpers'

# Ported from https://github.com/Operational-Transformation/ot.js/blob/master/test/lib/test-text-operation.js

describe OT::TextOperation do
  subject(:o) { OT::TextOperation.new }
  let(:h) { Helpers.new }

  n = 500

  it 'should test lengths' do
    expect(o.baseLength).to eq 0
    expect(o.targetLength).to eq 0

    o.retain(5)

    expect(o.baseLength).to eq 5
    expect(o.targetLength).to eq 5

    o.insert('abc')

    expect(o.baseLength).to eq 5
    expect(o.targetLength).to eq 8

    o.retain(2)

    expect(o.baseLength).to eq 7
    expect(o.targetLength).to eq 10

    o.delete(2)

    expect(o.baseLength).to eq 9
    expect(o.targetLength).to eq 10
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

      expect(o.baseLength).to eq str.length
      expect(o.targetLength).to eq o.apply(str).length
    end
  end

  it 'should correctly invert an OT operation' do
    n.times do
      str = h.random_string(50)
      o = h.random_operation(str)
      p = o.invert(str)

      expect(p.targetLength).to eq o.baseLength
      expect(p.baseLength).to eq o.targetLength

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

  it 'should correctly serialize and deserialize the transformation from JSON' do
    n.times do
      doc = h.random_string(50)
      operation = h.random_operation(doc)

      expect(operation).to eq OT::TextOperation.from_json(operation.to_json)
    end
  end

  it 'should correctly handle errors in json' do
    pending 'this test needs porting'

    # ops = [2, -1, -1, 'cde']
    # o = OT::TextOperation.from_json(ops)

    # expect(o.ops.length).to eq 3
    # expect(o.baseLength).to eq 4
    # expect(o.targetLength).to eq 5

    # function assertIncorrectAfter (fn) {
    #   ops2 = ops.slice(0)
    #   fn(ops2)
    #   test.throws(function () { TextOperation.fromJSON(ops2) })
    # }

    # assertIncorrectAfter(function (ops2) { ops2.push(insert: 'x') })
    # assertIncorrectAfter(function (ops2) { ops2.push(null) })
  end

  it 'should detect sequential operations that can be composed together for "natural" undo' do
    a = OT::TextOperation.new.retain(3)
    b = OT::TextOperation.new.retain(1).insert('tag').retain(2)

    expect(a).to be_composed_with b
    expect(b).to be_composed_with a

    a = OT::TextOperation.new.retain(1).insert('a').retain(2)
    b = OT::TextOperation.new.retain(2).insert('b').retain(2)
    expect(a).to be_composed_with b
    a.delete(3)
    expect(a).to_not be_composed_with b

    a = OT::TextOperation.new.retain(1).insert('b').retain(2)
    b = OT::TextOperation.new.retain(1).insert('a').retain(3)
    expect(a).to_not be_composed_with b

    a = OT::TextOperation.new.retain(4).delete(3).retain(10)
    b = OT::TextOperation.new.retain(2).delete(2).retain(10)
    expect(a).to be_composed_with b

    b = OT::TextOperation.new.retain(4).delete(7).retain(3)
    expect(a).to be_composed_with b

    b = OT::TextOperation.new.retain(2).delete(9).retain(3)
    expect(a).to_not be_composed_with b
  end

  it 'checks if two operations could be composed together if they were inverted' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)

      a_inv = a.invert(str)
      after_a = a.apply(str)

      b = h.random_operation(after_a)
      b_inv = b.invert(after_a)

      expect(b_inv.shouldBeComposedWithInverted(a_inv)).to eq a.shouldBeComposedWith(b)
    end
  end

  it 'should compose operations' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)

      after_a = a.apply(str)
      expect(after_a.length).to eq a.targetLength

      b = h.random_operation(after_a)
      after_b = b.apply(after_a)
      expect(after_b.length).to eq b.targetLength

      ab = a.compose(b)
      expect(a.meta).to eq ab.meta
      expect(b.targetLength).to eq ab.targetLength

      after_ab = ab.apply(str)
      expect(after_ab).to eq after_b
    end
  end

  it 'should be able to transform operations' do
    n.times do
      str = h.random_string(20)
      a = h.random_operation(str)
      b = h.random_operation(str)

      primes = TextOperation.transform(a, b)
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

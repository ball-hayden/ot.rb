module OT
  class TextOperation
    attr_reader :ops, :base_length, :target_length

    def initialize
      # When an operation is applied to an input string, you can think of this as
      # if an imaginary cursor runs over the entire string and skips over some
      # parts, deletes some parts and inserts characters at some positions. These
      # actions (skip/delete/insert) are stored as an array in the "ops" property.
      @ops = []
      # An operation's base_length is the length of every string the operation
      # can be applied to.
      @base_length = 0
      # The target_length is the length of every string that results from applying
      # the operation on a valid input string.
      @target_length = 0
    end

    def ==(other)
      return false unless base_length == other.base_length
      return false unless target_length == other.target_length
      return false unless ops.length == other.ops.length

      ops.length.times do |i|
        return false unless ops[i] == other.ops[i]
      end

      return true
    end

    # Operation are essentially lists of ops. There are three types of ops:
    #
    # * Retain ops: Advance the cursor position by a given number of characters.
    #   Represented by positive ints.
    # * Insert ops: Insert a given string at the current cursor position.
    #   Represented by strings.
    # * Delete ops: Delete the next n characters. Represented by negative ints.

    def self.retain_op?(op)
      op.is_a?(Integer) && op > 0
    end

    def retain_op?(op)
      TextOperation.retain_op?(op)
    end

    def self.insert_op?(op)
      op.is_a? String
    end

    def insert_op?(op)
      TextOperation.insert_op?(op)
    end

    def self.delete_op?(op)
      op.is_a?(Integer) && op < 0
    end

    def delete_op?(op)
      TextOperation.delete_op?(op)
    end

    # After an operation is constructed, the user of the library can specify the
    # actions of an operation (skip/insert/delete) with these three builder
    # methods. They all return the operation for convenient chaining.

    # Skip over a given number of characters.
    def retain(n)
      fail 'retain expects an integer' unless n.is_a? Integer

      return self if n == 0

      @base_length += n
      @target_length += n

      if retain_op?(@ops.last)
        # The last op is a retain op => we can merge them into one op.
        @ops[-1] += n
      else
        # Create a new op.
        @ops.push(n)
      end

      return self
    end

    # Insert a string at the current position.
    def insert(str)
      fail 'insert expects a string' unless str.is_a? String

      return self if str == ''

      @target_length += str.length

      if insert_op?(ops.last)
        # Merge insert op.
        @ops[-1] += str
      elsif delete_op?(ops.last)
        # It doesn't matter when an operation is applied whether the operation
        # is delete(3), insert("something") or insert("something"), delete(3).
        # Here we enforce that in this case, the insert op always comes first.
        # This makes all operations that have the same effect when applied to
        # a document of the right length equal in respect to the `equals` method.
        if insert_op?(ops[-2])
          @ops[-2] += str
        else
          @ops.insert(-2, str)
        end
      else
        @ops.push(str)
      end

      return self
    end

    # Delete a string at the current position.
    def delete(n)
      fail 'delete expects an integer or a string' unless n.is_a?(Integer) || n.is_a?(String)

      n = n.length if n.is_a? String

      return self if n == 0

      n = -n if n > 0

      @base_length -= n

      if delete_op?(@ops.last)
        @ops[-1] += n
      else
        @ops.push(n)
      end

      return self
    end

    # Tests whether this operation has no effect.
    def noop?
      return @ops.length == 0 || (@ops.length == 1 && retain_op?(@ops[0]))
    end

    # Pretty printing.
    def to_s
      # map: build a new array by applying a function to every element in an old
      # array.
      @ops.map do |op|
        if retain_op?(op)
          "retain #{op}"
        elsif insert_op?(op)
          "insert '#{op}'"
        else
          "delete #{-op}"
        end
      end.join(', ')
    end

    # Converts operation into an array value.
    # Note that this replaces the toJSON method in ot.js
    def to_a
      return @ops
    end

    # Converts an array into an operation and validates it.
    # Note that this replaces the fromJSON method in ot.js
    def self.from_a(ops)
      operation = TextOperation.new

      ops.each do |op|
        if retain_op?(op)
          operation.retain(op)
        elsif insert_op?(op)
          operation.insert(op)
        elsif delete_op?(op)
          operation.delete(op)
        else
          fail 'unknown operation: ' + op.to_s
        end
      end

      return operation
    end

    # Apply an operation to a string, returning a new string. Throws an error if
    # there's a mismatch between the input string and the operation.
    def apply(str)
      if str.length != base_length
        fail "The operation's base length must be equal to the string's length."
      end

      new_str = ''
      str_index = 0

      @ops.each do |op|
        if retain_op?(op)
          if (str_index + op) > str.length
            fail "Operation can't retain more characters than are left in the string."
          end

          # Copy skipped part of the old string.
          new_str += str.slice(str_index, op)
          str_index += op
        elsif insert_op?(op)
          # Insert string.
          new_str += op
        else
          # delete op
          str_index -= op
        end
      end

      if (str_index != str.length)
        fail "The operation didn't operate on the whole string."
      end

      return new_str
    end

    # Computes the inverse of an operation. The inverse of an operation is the
    # operation that reverts the effects of the operation, e.g. when you have an
    # operation 'insert("hello "); skip(6);' then the inverse is 'delete("hello ");
    # skip(6);'. The inverse should be used for implementing undo.
    def invert(str)
      str_index = 0
      inverse = TextOperation.new

      @ops.each do |op|
        if retain_op?(op)
          inverse.retain(op)
          str_index += op
        elsif insert_op?(op)
          inverse.delete(op.length)
        else # delete op
          inverse.insert(str.slice(str_index, -op))
          str_index -= op
        end
      end

      return inverse
    end

    # Compose merges two consecutive operations into one operation, that
    # preserves the changes of both. Or, in other words, for each input string S
    # and a pair of consecutive operations A and B,
    # apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.
    def compose(operation2)
      operation1 = self
      if operation1.target_length != operation2.base_length
        fail 'The base length of the second operation has to be the target length of the first operation'
      end

      operation = TextOperation.new; # the combined operation

      # for fast access
      ops1 = operation1.ops
      ops2 = operation2.ops

      # current index into ops1 respectively ops2
      i1 = 0
      i2 = 0

      # current ops
      op1 = ops1[i1]
      op2 = ops2[i2]

      loop do
        # Dispatch on the type of op1 and op2
        if op1.nil? && op2.nil?
          # end condition: both ops1 and ops2 have been processed
          break
        end

        if delete_op?(op1)
          operation.delete(op1)

          op1 = ops1[i1 += 1]
          next
        end

        if insert_op?(op2)
          operation.insert(op2)

          op2 = ops2[i2 += 1]
          next
        end

        if op1.nil?
          fail 'Cannot compose operations: first operation is too short.'
        end
        if op2.nil?
          fail 'Cannot compose operations: first operation is too long.'
        end

        if retain_op?(op1) && retain_op?(op2)
          if op1 > op2
            operation.retain(op2)
            op1 -= op2

            op2 = ops2[i2 += 1]
          elsif (op1 == op2)
            operation.retain(op1)

            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            operation.retain(op1)
            op2 -= op1

            op1 = ops1[i1 += 1]
          end
        elsif insert_op?(op1) && delete_op?(op2)
          if op1.length > -op2
            op1 = op1.slice(-op2, op1.length)
            op2 = ops2[i2 += 1]
          elsif (op1.length == -op2)
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            op2 += op1.length
            op1 = ops1[i1 += 1]
          end
        elsif insert_op?(op1) && retain_op?(op2)
          if op1.length > op2
            operation.insert(op1.slice(0, op2))
            op1 = op1.slice(op2, op1.length - op2)
            op2 = ops2[i2 += 1]
          elsif (op1.length == op2)
            operation.insert(op1)
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            operation.insert(op1)
            op2 -= op1.length
            op1 = ops1[i1 += 1]
          end
        elsif retain_op?(op1) && delete_op?(op2)
          if op1 > -op2
            operation.delete(op2)
            op1 += op2
            op2 = ops2[i2 += 1]
          elsif (op1 == -op2)
            operation.delete(op2)
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            operation.delete(op1)
            op2 += op1
            op1 = ops1[i1 += 1]
          end
        else
          fail "This shouldn't happen: op1: " +
            JSON.stringify(op1) + ', op2: ' +
            JSON.stringify(op2)
        end
      end

      return operation
    end

    def self.get_simple_op(operation)
      ops = operation.ops

      case (ops.length)
      when 1
        return ops[0]
      when 2
        return retain_op?(ops[0]) ? ops[1] : (retain_op?(ops[1]) ? ops[0] : nil)
      when 3
        return ops[1] if retain_op?(ops[0]) && retain_op?(ops[2])
      end

      return
    end

    def self.get_start_index(operation)
      return operation.ops[0] if retain_op?(operation.ops[0])
      return 0
    end

    # When you use ctrl-z to undo your latest changes, you expect the program not
    # to undo every single keystroke but to undo your last sentence you wrote at
    # a stretch or the deletion you did by holding the backspace key down. This
    # This can be implemented by composing operations on the undo stack. This
    # method can help decide whether two operations should be composed. It
    # returns true if the operations are consecutive insert operations or both
    # operations delete text at the same position. You may want to include other
    # factors like the time since the last change in your decision.
    def compose_with?(other)
      return true if noop? || other.noop?

      start_a = TextOperation.get_start_index(self)
      start_b = TextOperation.get_start_index(other)

      simple_a = TextOperation.get_simple_op(self)
      simple_b = TextOperation.get_simple_op(other)

      return false unless simple_a && simple_b

      if insert_op?(simple_a) && insert_op?(simple_b)
        return start_a + simple_a.length == start_b
      end

      if delete_op?(simple_a) && delete_op?(simple_b)
        # there are two possibilities to delete: with backspace and with the
        # delete key.
        return (start_b - simple_b == start_a) || start_a == start_b
      end

      return false
    end

    # Decides whether two operations should be composed with each other
    # if they were inverted, that is
    # `shouldBeComposedWith(a, b) = shouldBeComposedWithInverted(b^{-1}, a^{-1})`.
    def compose_with_inverted?(other)
      return true if noop? || other.noop?

      start_a = TextOperation.get_start_index(self)
      start_b = TextOperation.get_start_index(other)

      simple_a = TextOperation.get_simple_op(self)
      simple_b = TextOperation.get_simple_op(other)

      return false unless simple_a && simple_b

      if insert_op?(simple_a) && insert_op?(simple_b)
        return start_a + simple_a.length == start_b || start_a == start_b
      end

      if delete_op?(simple_a) && delete_op?(simple_b)
        return start_b - simple_b == start_a
      end

      return false
    end

    # Transform takes two operations A and B that happened concurrently and
    # produces two operations A' and B' (in an array) such that
    # `apply(apply(S, A), B') = apply(apply(S, B), A')`. This function is the
    # heart of OT.
    def self.transform(operation1, operation2)
      if (operation1.base_length != operation2.base_length)
        fail 'Both operations have to have the same base length'
      end

      operation1prime = TextOperation.new
      operation2prime = TextOperation.new

      ops1 = operation1.ops
      ops2 = operation2.ops

      i1 = 0
      i2 = 0

      op1 = ops1[i1]
      op2 = ops2[i2]

      loop do
        # At every iteration of the loop, the imaginary cursor that both
        # operation1 and operation2 have that operates on the input string must
        # have the same position in the input string.

        if op1.nil? && op2.nil?
          # end condition: both ops1 and ops2 have been processed
          break
        end

        # next two cases: one or both ops are insert ops
        # => insert the string in the corresponding prime operation, skip it in
        # the other one. If both op1 and op2 are insert ops, prefer op1.
        if insert_op?(op1)
          operation1prime.insert(op1)
          operation2prime.retain(op1.length)
          op1 = ops1[i1 += 1]
          next
        end

        if insert_op?(op2)
          operation1prime.retain(op2.length)
          operation2prime.insert(op2)
          op2 = ops2[i2 += 1]
          next
        end

        if op1.nil?
          fail 'Cannot transform operations: first operation is too short.'
        end
        if op2.nil?
          fail 'Cannot transform operations: first operation is too long.'
        end

        minl = nil

        if retain_op?(op1) && retain_op?(op2)
          # Simple case: retain/retain
          if op1 > op2
            minl = op2
            op1 -= op2
            op2 = ops2[i2 += 1]
          elsif (op1 == op2)
            minl = op2
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            minl = op1
            op2 -= op1
            op1 = ops1[i1 += 1]
          end

          operation1prime.retain(minl)
          operation2prime.retain(minl)
        elsif delete_op?(op1) && delete_op?(op2)
          # Both operations delete the same string at the same position. We don't
          # need to produce any operations, we just skip over the delete ops and
          # handle the case that one operation deletes more than the other.
          if -op1 > -op2
            op1 -= op2
            op2 = ops2[i2 += 1]
          elsif (op1 == op2)
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            op2 -= op1
            op1 = ops1[i1 += 1]
          end
        # next two cases: delete/retain and retain/delete
        elsif delete_op?(op1) && retain_op?(op2)
          if -op1 > op2
            minl = op2
            op1 += op2
            op2 = ops2[i2 += 1]
          elsif (-op1 == op2)
            minl = op2
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            minl = -op1
            op2 += op1
            op1 = ops1[i1 += 1]
          end

          operation1prime.delete(minl)
        elsif retain_op?(op1) && delete_op?(op2)
          if op1 > -op2
            minl = -op2
            op1 += op2
            op2 = ops2[i2 += 1]
          elsif (op1 == -op2)
            minl = op1
            op1 = ops1[i1 += 1]
            op2 = ops2[i2 += 1]
          else
            minl = op1
            op2 += op1
            op1 = ops1[i1 += 1]
          end

          operation2prime.delete(minl)
        else
          throw new Error("The two operations aren't compatible")
        end
      end

      return [operation1prime, operation2prime]
    end
  end
end

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

    # # Tests whether this operation has no effect.
    # TextOperation.prototype.isNoop = function () {
    #   return @ops.length === 0 || (@ops.length === 1 && retain_op?(@ops[0]));
    # };
    #
    # # Pretty printing.
    # TextOperation.prototype.toString = function () {
    #   # map: build a new array by applying a function to every element in an old
    #   # array.
    #   var map = Array.prototype.map || function (fn) {
    #     var arr = this;
    #     var newArr = [];
    #     for (var i = 0, l = arr.length; i < l; i++) {
    #       newArr[i] = fn(arr[i]);
    #     }
    #     return newArr;
    #   };
    #   return map.call(@ops, function (op) {
    #     if (retain_op?(op)) {
    #       return "retain " + op;
    #     } else if (insert_op?(op)) {
    #       return "insert '" + op + "'";
    #     } else {
    #       return "delete " + (-op);
    #     }
    #   }).join(', ');
    # };
    #
    # # Converts operation into a JSON value.
    # TextOperation.prototype.toJSON = function () {
    #   return @ops;
    # };
    #
    # # Converts a plain JS object into an operation and validates it.
    # TextOperation.fromJSON = function (ops) {
    #   var o = new TextOperation();
    #   for (var i = 0, l = ops.length; i < l; i++) {
    #     var op = ops[i];
    #     if (retain_op?(op)) {
    #       o.retain(op);
    #     } else if (insert_op?(op)) {
    #       o.insert(op);
    #     } else if (delete_op?(op)) {
    #       o['delete'](op);
    #     } else {
    #       throw new Error("unknown operation: " + JSON.stringify(op));
    #     }
    #   }
    #   return o;
    # };

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

    # # Computes the inverse of an operation. The inverse of an operation is the
    # # operation that reverts the effects of the operation, e.g. when you have an
    # # operation 'insert("hello "); skip(6);' then the inverse is 'delete("hello ");
    # # skip(6);'. The inverse should be used for implementing undo.
    # TextOperation.prototype.invert = function (str) {
    #   var str_index = 0;
    #   var inverse = new TextOperation();
    #   var ops = @ops;
    #   for (var i = 0, l = ops.length; i < l; i++) {
    #     var op = ops[i];
    #     if (retain_op?(op)) {
    #       inverse.retain(op);
    #       str_index += op;
    #     } else if (insert_op?(op)) {
    #       inverse['delete'](op.length);
    #     } else { # delete op
    #       inverse.insert(str.slice(str_index, str_index - op));
    #       str_index -= op;
    #     }
    #   }
    #   return inverse;
    # };
    #
    # # Compose merges two consecutive operations into one operation, that
    # # preserves the changes of both. Or, in other words, for each input string S
    # # and a pair of consecutive operations A and B,
    # # apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.
    # TextOperation.prototype.compose = function (operation2) {
    #   var operation1 = this;
    #   if (operation1.target_length !== operation2.base_length) {
    #     throw new Error("The base length of the second operation has to be the target length of the first operation");
    #   }
    #
    #   var operation = new TextOperation(); # the combined operation
    #   var ops1 = operation1.ops, ops2 = operation2.ops; # for fast access
    #   var i1 = 0, i2 = 0; # current index into ops1 respectively ops2
    #   var op1 = ops1[i1++], op2 = ops2[i2++]; # current ops
    #   while (true) {
    #     # Dispatch on the type of op1 and op2
    #     if (typeof op1 === 'undefined' && typeof op2 === 'undefined') {
    #       # end condition: both ops1 and ops2 have been processed
    #       break;
    #     }
    #
    #     if (delete_op?(op1)) {
    #       operation['delete'](op1);
    #       op1 = ops1[i1++];
    #       continue;
    #     }
    #     if (insert_op?(op2)) {
    #       operation.insert(op2);
    #       op2 = ops2[i2++];
    #       continue;
    #     }
    #
    #     if (typeof op1 === 'undefined') {
    #       throw new Error("Cannot compose operations: first operation is too short.");
    #     }
    #     if (typeof op2 === 'undefined') {
    #       throw new Error("Cannot compose operations: first operation is too long.");
    #     }
    #
    #     if (retain_op?(op1) && retain_op?(op2)) {
    #       if (op1 > op2) {
    #         operation.retain(op2);
    #         op1 = op1 - op2;
    #         op2 = ops2[i2++];
    #       } else if (op1 === op2) {
    #         operation.retain(op1);
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         operation.retain(op1);
    #         op2 = op2 - op1;
    #         op1 = ops1[i1++];
    #       }
    #     } else if (insert_op?(op1) && delete_op?(op2)) {
    #       if (op1.length > -op2) {
    #         op1 = op1.slice(-op2);
    #         op2 = ops2[i2++];
    #       } else if (op1.length === -op2) {
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         op2 = op2 + op1.length;
    #         op1 = ops1[i1++];
    #       }
    #     } else if (insert_op?(op1) && retain_op?(op2)) {
    #       if (op1.length > op2) {
    #         operation.insert(op1.slice(0, op2));
    #         op1 = op1.slice(op2);
    #         op2 = ops2[i2++];
    #       } else if (op1.length === op2) {
    #         operation.insert(op1);
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         operation.insert(op1);
    #         op2 = op2 - op1.length;
    #         op1 = ops1[i1++];
    #       }
    #     } else if (retain_op?(op1) && delete_op?(op2)) {
    #       if (op1 > -op2) {
    #         operation['delete'](op2);
    #         op1 = op1 + op2;
    #         op2 = ops2[i2++];
    #       } else if (op1 === -op2) {
    #         operation['delete'](op2);
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         operation['delete'](op1);
    #         op2 = op2 + op1;
    #         op1 = ops1[i1++];
    #       }
    #     } else {
    #       throw new Error(
    #         "This shouldn't happen: op1: " +
    #         JSON.stringify(op1) + ", op2: " +
    #         JSON.stringify(op2)
    #       );
    #     }
    #   }
    #   return operation;
    # };
    #
    # function getSimpleOp (operation, fn) {
    #   var ops = operation.ops;
    #   var retain_op? = TextOperation.retain_op?;
    #   switch (ops.length) {
    #   case 1:
    #     return ops[0];
    #   case 2:
    #     return retain_op?(ops[0]) ? ops[1] : (retain_op?(ops[1]) ? ops[0] : null);
    #   case 3:
    #     if (retain_op?(ops[0]) && retain_op?(ops[2])) { return ops[1]; }
    #   }
    #   return null;
    # }
    #
    # function getStartIndex (operation) {
    #   if (retain_op?(operation.ops[0])) { return operation.ops[0]; }
    #   return 0;
    # }
    #
    # # When you use ctrl-z to undo your latest changes, you expect the program not
    # # to undo every single keystroke but to undo your last sentence you wrote at
    # # a stretch or the deletion you did by holding the backspace key down. This
    # # This can be implemented by composing operations on the undo stack. This
    # # method can help decide whether two operations should be composed. It
    # # returns true if the operations are consecutive insert operations or both
    # # operations delete text at the same position. You may want to include other
    # # factors like the time since the last change in your decision.
    # TextOperation.prototype.shouldBeComposedWith = function (other) {
    #   if (this.isNoop() || other.isNoop()) { return true; }
    #
    #   var startA = getStartIndex(this), startB = getStartIndex(other);
    #   var simpleA = getSimpleOp(this), simpleB = getSimpleOp(other);
    #   if (!simpleA || !simpleB) { return false; }
    #
    #   if (insert_op?(simpleA) && insert_op?(simpleB)) {
    #     return startA + simpleA.length === startB;
    #   }
    #
    #   if (delete_op?(simpleA) && delete_op?(simpleB)) {
    #     # there are two possibilities to delete: with backspace and with the
    #     # delete key.
    #     return (startB - simpleB === startA) || startA === startB;
    #   }
    #
    #   return false;
    # };
    #
    # # Decides whether two operations should be composed with each other
    # # if they were inverted, that is
    # # `shouldBeComposedWith(a, b) = shouldBeComposedWithInverted(b^{-1}, a^{-1})`.
    # TextOperation.prototype.shouldBeComposedWithInverted = function (other) {
    #   if (this.isNoop() || other.isNoop()) { return true; }
    #
    #   var startA = getStartIndex(this), startB = getStartIndex(other);
    #   var simpleA = getSimpleOp(this), simpleB = getSimpleOp(other);
    #   if (!simpleA || !simpleB) { return false; }
    #
    #   if (insert_op?(simpleA) && insert_op?(simpleB)) {
    #     return startA + simpleA.length === startB || startA === startB;
    #   }
    #
    #   if (delete_op?(simpleA) && delete_op?(simpleB)) {
    #     return startB - simpleB === startA;
    #   }
    #
    #   return false;
    # };
    #
    # # Transform takes two operations A and B that happened concurrently and
    # # produces two operations A' and B' (in an array) such that
    # # `apply(apply(S, A), B') = apply(apply(S, B), A')`. This function is the
    # # heart of OT.
    # TextOperation.transform = function (operation1, operation2) {
    #   if (operation1.base_length !== operation2.base_length) {
    #     throw new Error("Both operations have to have the same base length");
    #   }
    #
    #   var operation1prime = new TextOperation();
    #   var operation2prime = new TextOperation();
    #   var ops1 = operation1.ops, ops2 = operation2.ops;
    #   var i1 = 0, i2 = 0;
    #   var op1 = ops1[i1++], op2 = ops2[i2++];
    #   while (true) {
    #     # At every iteration of the loop, the imaginary cursor that both
    #     # operation1 and operation2 have that operates on the input string must
    #     # have the same position in the input string.
    #
    #     if (typeof op1 === 'undefined' && typeof op2 === 'undefined') {
    #       # end condition: both ops1 and ops2 have been processed
    #       break;
    #     }
    #
    #     # next two cases: one or both ops are insert ops
    #     # => insert the string in the corresponding prime operation, skip it in
    #     # the other one. If both op1 and op2 are insert ops, prefer op1.
    #     if (insert_op?(op1)) {
    #       operation1prime.insert(op1);
    #       operation2prime.retain(op1.length);
    #       op1 = ops1[i1++];
    #       continue;
    #     }
    #     if (insert_op?(op2)) {
    #       operation1prime.retain(op2.length);
    #       operation2prime.insert(op2);
    #       op2 = ops2[i2++];
    #       continue;
    #     }
    #
    #     if (typeof op1 === 'undefined') {
    #       throw new Error("Cannot compose operations: first operation is too short.");
    #     }
    #     if (typeof op2 === 'undefined') {
    #       throw new Error("Cannot compose operations: first operation is too long.");
    #     }
    #
    #     var minl;
    #     if (retain_op?(op1) && retain_op?(op2)) {
    #       # Simple case: retain/retain
    #       if (op1 > op2) {
    #         minl = op2;
    #         op1 = op1 - op2;
    #         op2 = ops2[i2++];
    #       } else if (op1 === op2) {
    #         minl = op2;
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         minl = op1;
    #         op2 = op2 - op1;
    #         op1 = ops1[i1++];
    #       }
    #       operation1prime.retain(minl);
    #       operation2prime.retain(minl);
    #     } else if (delete_op?(op1) && delete_op?(op2)) {
    #       # Both operations delete the same string at the same position. We don't
    #       # need to produce any operations, we just skip over the delete ops and
    #       # handle the case that one operation deletes more than the other.
    #       if (-op1 > -op2) {
    #         op1 = op1 - op2;
    #         op2 = ops2[i2++];
    #       } else if (op1 === op2) {
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         op2 = op2 - op1;
    #         op1 = ops1[i1++];
    #       }
    #     # next two cases: delete/retain and retain/delete
    #     } else if (delete_op?(op1) && retain_op?(op2)) {
    #       if (-op1 > op2) {
    #         minl = op2;
    #         op1 = op1 + op2;
    #         op2 = ops2[i2++];
    #       } else if (-op1 === op2) {
    #         minl = op2;
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         minl = -op1;
    #         op2 = op2 + op1;
    #         op1 = ops1[i1++];
    #       }
    #       operation1prime['delete'](minl);
    #     } else if (retain_op?(op1) && delete_op?(op2)) {
    #       if (op1 > -op2) {
    #         minl = -op2;
    #         op1 = op1 + op2;
    #         op2 = ops2[i2++];
    #       } else if (op1 === -op2) {
    #         minl = op1;
    #         op1 = ops1[i1++];
    #         op2 = ops2[i2++];
    #       } else {
    #         minl = op1;
    #         op2 = op2 + op1;
    #         op1 = ops1[i1++];
    #       }
    #       operation2prime['delete'](minl);
    #     } else {
    #       throw new Error("The two operations aren't compatible");
    #     }
    #   }
    #
    #   return [operation1prime, operation2prime];
    # };
  end
end

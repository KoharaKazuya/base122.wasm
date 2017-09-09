(module
  (import "glue" "mem" (memory 0))

  (func (export "encode") (param $offset i32)
    (local $length i32)
    (local $current_bit_index i64)
    (local $current_char_index i32)
    (local $encoded_utf8_char i32)
    (local $end_bit_index i64)

    ;; init
    ;; init: $length
    get_local $offset
    i32.load
    set_local $length
    ;; init: $current_bit_index
    get_local $offset
    i32.const 4
    i32.add
    i64.extend_s/i32
    i64.const 8
    i64.mul
    set_local $current_bit_index
    ;; init: $current_char_index
    get_local $offset
    get_local $length
    i32.const 9
    i32.add
    i32.add
    set_local $current_char_index
    ;; init: $end_bit_index
    get_local $offset
    get_local $length
    i32.const 4
    i32.add
    i32.add
    i64.extend_s/i32
    i64.const 8
    i64.mul
    set_local $end_bit_index

    block $read_loop_end
      loop $read_loop

        ;; break if no remain bits
        get_local $current_bit_index
        get_local $end_bit_index
        i64.ge_s
        br_if $read_loop_end

        get_local $current_bit_index
        get_local $end_bit_index
        call $read_char
        set_local $encoded_utf8_char

        ;; write utf8 char to memory
        get_local $encoded_utf8_char
        i32.const 0xff
        i32.le_s
        if
          get_local $current_char_index
          get_local $encoded_utf8_char
          i32.store8
        else
          ;; higher bits
          get_local $current_char_index
          get_local $encoded_utf8_char
          i32.const 8
          i32.shr_s
          i32.store8
          ;; lower bits
          get_local $current_char_index
          i32.const 1
          i32.add
          get_local $encoded_utf8_char
          i32.store8
        end

        ;; step 7bit or 14bit
        get_local $encoded_utf8_char
        i32.const 0xff
        i32.le_s
        if
          ;; $current_bit_index += 7
          get_local $current_bit_index
          i64.const 7
          i64.add
          set_local $current_bit_index
          ;; $current_char_index += 1
          get_local $current_char_index
          i32.const 1
          i32.add
          set_local $current_char_index
        else
          ;; $current_bit_index += 14
          get_local $current_bit_index
          i64.const 14
          i64.add
          set_local $current_bit_index
          ;; $current_char_index += 2
          get_local $current_char_index
          i32.const 2
          i32.add
          set_local $current_char_index
        end

        br $read_loop
      end
    end

    ;; set output size
    get_local $offset
    get_local $length
    i32.const 5
    i32.add
    i32.add
    get_local $current_char_index
    get_local $offset
    get_local $length
    i32.const 9
    i32.add
    i32.add
    i32.sub
    i32.store)

  (func $read_char (param $bit_index i64) (param $end_bit_index i64) (result i32)
    (local $bits i32)
    (local $illegal_code i32)
    (local $illegal_extra_bits i32)

    get_local $bit_index
    call $read_7bits
    set_local $bits

    block $illegal_char

      ;; null
      get_local $bits
      i32.const 0
      i32.eq
      if
        i32.const 0
        set_local $illegal_code
        br $illegal_char
      end

      ;; newline
      get_local $bits
      i32.const 10
      i32.eq
      if
        i32.const 1
        set_local $illegal_code
        br $illegal_char
      end

      ;; carriage return
      get_local $bits
      i32.const 13
      i32.eq
      if
        i32.const 2
        set_local $illegal_code
        br $illegal_char
      end

      ;; double quote
      get_local $bits
      i32.const 34
      i32.eq
      if
        i32.const 3
        set_local $illegal_code
        br $illegal_char
      end

      ;; ampersand
      get_local $bits
      i32.const 38
      i32.eq
      if
        i32.const 4
        set_local $illegal_code
        br $illegal_char
      end

      ;; backslash
      get_local $bits
      i32.const 92
      i32.eq
      if
        i32.const 5
        set_local $illegal_code
        br $illegal_char
      end

      ;; normal character
      get_local $bits
      return
    end

    ;; terminal character
    get_local $bit_index
    i64.const 7
    i64.add
    get_local $end_bit_index
    i64.ge_s
    if
      ;; 0b110sss1x 0x10xxxxxx (sss: 0b111, xxxxxxxx: $illegal_code)
      ;; higher
      i32.const 0xde
      get_local $illegal_code
      i32.const 7
      i32.shr_u
      i32.or
      i32.const 8
      i32.shl
      ;; lower
      i32.const 0x80
      get_local $illegal_code
      i32.const 0x3f
      i32.and
      i32.or
      i32.or
      return
    end

    get_local $bit_index
    i64.const 7
    i64.add
    call $read_7bits
    set_local $illegal_extra_bits

    ;; 0b110sss1x 0x10xxxxxx (sss: $illegal_code, xxxxxxxx: $illegal_extra_bits)
    ;; higher
    i32.const 0xc2
    get_local $illegal_code
    i32.const 2
    i32.shl
    i32.or
    get_local $illegal_extra_bits
    i32.const 6
    i32.shr_u
    i32.or
    i32.const 8
    i32.shl

    ;; lower
    i32.const 0x80
    get_local $illegal_extra_bits
    i32.const 0x3f
    i32.and
    i32.or

    i32.or)

  (func $read_7bits (param $bit_index i64) (result i32)
    (local $char_index i32)
    (local $bit_of_byte i32)

    get_local $bit_index
    i64.const 8
    i64.div_s
    i32.wrap/i64
    set_local $char_index

    get_local $bit_index
    get_local $char_index
    i64.extend_s/i32
    i64.const 8
    i64.mul
    i64.sub
    i32.wrap/i64
    set_local $bit_of_byte

    get_local $bit_of_byte
    i32.const 0
    i32.eq
    if
      get_local $char_index
      i32.load8_u
      i32.const 1
      i32.shr_u
      return
    end

    get_local $bit_of_byte
    i32.const 1
    i32.eq
    if
      get_local $char_index
      i32.load8_u
      i32.const 0x7f
      i32.and
      return
    end

    get_local $char_index
    i32.load8_u
    get_local $bit_of_byte
    i32.const 1
    i32.sub
    i32.shl
    i32.const 0x7f
    i32.and

    get_local $char_index
    i32.const 1
    i32.add
    i32.load8_u
    i32.const 9
    get_local $bit_of_byte
    i32.sub
    i32.shr_u

    i32.or)

  (func (export "decode") (param $offset i32)
    (local $length i32)
    (local $current_char_index i32)
    (local $end_char_index i32)
    (local $current_byte_index i32)
    (local $current_bit_pos i32)
    (local $current_byte i32)
    (local $encoded_byte i32)
    (local $illegal_code i32)
    (local $illegal_byte i32)

    ;; init
    ;; init: $length
    get_local $offset
    i32.load
    set_local $length
    ;; init: $current_char_index
    get_local $offset
    i32.const 4
    i32.add
    set_local $current_char_index
    ;; init: $end_char_index
    get_local $offset
    i32.const 4
    get_local $length
    i32.add
    i32.add
    set_local $end_char_index
    ;; init: $current_byte_index
    get_local $offset
    get_local $length
    i32.const 9
    i32.add
    i32.add
    set_local $current_byte_index
    ;; init: $current_bit_pos
    i32.const 0
    set_local $current_bit_pos
    ;; init: $current_byte
    i32.const 0
    set_local $current_byte

    block $read_loop_end
      loop $read_loop

        ;; break if no remain char
        get_local $current_char_index
        get_local $end_char_index
        i32.ge_s
        br_if $read_loop_end

        ;; read byte
        get_local $current_char_index
        i32.load8_u
        tee_local $encoded_byte

        ;; 0b0xxxxxxx
        i32.const 0x80
        i32.and
        i32.const 0
        i32.eq
        if
          get_local $encoded_byte
          i32.const 1
          i32.shl
          get_local $current_bit_pos
          i32.shr_u
          get_local $current_byte
          i32.or
          set_local $current_byte

          get_local $current_bit_pos
          i32.const 7
          i32.add
          tee_local $current_bit_pos
          i32.const 8
          i32.ge_s
          if
            get_local $current_byte_index
            get_local $current_byte
            i32.store8

            get_local $current_byte_index
            i32.const 1
            i32.add
            set_local $current_byte_index

            get_local $current_bit_pos
            i32.const 8
            i32.sub
            set_local $current_bit_pos

            get_local $encoded_byte
            i32.const 8
            get_local $current_bit_pos
            i32.sub
            i32.shl
            i32.const 0xff
            i32.and
            set_local $current_byte
          end
        else
          get_local $encoded_byte
          i32.const 0xe2
          i32.and
          i32.const 0xc2
          i32.eq
          if
            ;; 0b110sss1x
            get_local $encoded_byte
            i32.const 2
            i32.shr_u
            i32.const 7
            i32.and
            set_local $illegal_code

            block $set_illegal_char

              ;; null
              get_local $illegal_code
              i32.const 0
              i32.eq
              if
                i32.const 0
                set_local $illegal_byte
              end

              ;; newline
              get_local $illegal_code
              i32.const 1
              i32.eq
              if
                i32.const 10
                set_local $illegal_byte
              end

              ;; carriage return
              get_local $illegal_code
              i32.const 2
              i32.eq
              if
                i32.const 13
                set_local $illegal_byte
              end

              ;; double quote
              get_local $illegal_code
              i32.const 3
              i32.eq
              if
                i32.const 34
                set_local $illegal_byte
              end

              ;; ampersand
              get_local $illegal_code
              i32.const 4
              i32.eq
              if
                i32.const 38
                set_local $illegal_byte
              end

              ;; backslash
              get_local $illegal_code
              i32.const 5
              i32.eq
              if
                i32.const 92
                set_local $illegal_byte
              end

              ;; 0b111
              get_local $illegal_code
              i32.const 7
              i32.eq
              if
                get_local $encoded_byte
                i32.const 1
                i32.and
                i32.const 7
                get_local $current_bit_pos
                i32.sub
                i32.shl
                get_local $current_byte
                i32.or
                set_local $current_byte

                get_local $current_bit_pos
                i32.const 1
                i32.add
                tee_local $current_bit_pos
                i32.const 8
                i32.ge_s
                if
                  get_local $current_byte_index
                  get_local $current_byte
                  i32.store8

                  get_local $current_byte_index
                  i32.const 1
                  i32.add
                  set_local $current_byte_index

                  i32.const 0
                  set_local $current_byte

                  i32.const 0
                  set_local $current_bit_pos
                end

                br $set_illegal_char
              end

              get_local $current_byte_index
              get_local $illegal_byte
              i32.const 1
              i32.shl
              get_local $encoded_byte
              i32.const 1
              i32.and
              i32.or
              get_local $current_bit_pos
              i32.shr_s
              get_local $current_byte
              i32.or
              i32.store8

              get_local $current_byte_index
              i32.const 1
              i32.add
              set_local $current_byte_index

              get_local $illegal_byte
              i32.const 1
              i32.shl
              get_local $encoded_byte
              i32.const 1
              i32.and
              i32.or
              i32.const 8
              get_local $current_bit_pos
              i32.sub
              i32.shl
              i32.const 0xff
              i32.and
              set_local $current_byte
            end
          else
            ;; 0b10xxxxxx
            get_local $encoded_byte
            i32.const 0x3f
            i32.and
            i32.const 2
            i32.shl
            get_local $current_bit_pos
            i32.shr_u
            get_local $current_byte
            i32.or
            set_local $current_byte

            get_local $current_bit_pos
            i32.const 6
            i32.add
            tee_local $current_bit_pos
            i32.const 8
            i32.ge_s
            if
              get_local $current_byte_index
              get_local $current_byte
              i32.store8

              get_local $current_byte_index
              i32.const 1
              i32.add
              set_local $current_byte_index

              get_local $current_bit_pos
              i32.const 8
              i32.sub
              set_local $current_bit_pos

              get_local $encoded_byte
              i32.const 8
              get_local $current_bit_pos
              i32.sub
              i32.shl
              i32.const 0xff
              i32.and
              set_local $current_byte
            end
          end
        end

        get_local $current_char_index
        i32.const 1
        i32.add
        set_local $current_char_index

        br $read_loop
      end
    end

    ;; set output size
    get_local $offset
    get_local $length
    i32.const 5
    i32.add
    i32.add
    get_local $current_byte_index
    get_local $offset
    get_local $length
    i32.const 9
    i32.add
    i32.add
    i32.sub
    i32.store)
)

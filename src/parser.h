/*
 * Copyright (c) 2003-2008, John Wiegley.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * - Neither the name of New Artisans LLC nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _PARSER_H
#define _PARSER_H

#include "token.h"
#include "op.h"

namespace ledger {

class expr_t::parser_t : public noncopyable
{
#define EXPR_PARSE_NORMAL     0x00
#define EXPR_PARSE_PARTIAL    0x01
#define EXPR_PARSE_SINGLE     0x02
#define EXPR_PARSE_NO_MIGRATE 0x04
#define EXPR_PARSE_NO_REDUCE  0x08
#define EXPR_PARSE_NO_ASSIGN  0x10
#define EXPR_PARSE_NO_DATES   0x20

public:
  typedef uint_least8_t flags_t;

private:
  mutable token_t lookahead;
  mutable bool	  use_lookahead;

  token_t& next_token(std::istream& in, flags_t tflags) const
  {
    if (use_lookahead)
      use_lookahead = false;
    else
      lookahead.next(in, tflags);
    return lookahead;
  }

  void push_token(const token_t& tok) const
  {
    assert(&tok == &lookahead);
    use_lookahead = true;
  }

  void push_token() const
  {
    use_lookahead = true;
  }

  ptr_op_t parse_value_term(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_unary_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_mul_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_add_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_logic_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_and_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_or_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_querycolon_expr(std::istream& in, const flags_t flags) const;
  ptr_op_t parse_value_expr(std::istream& in, const flags_t flags) const;

public:
  parser_t() : use_lookahead(false) {
    TRACE_CTOR(parser_t, "");
  }
  ~parser_t() throw() {
    TRACE_DTOR(parser_t);
  }

  ptr_op_t parse(std::istream& in, const flags_t flags = EXPR_PARSE_NORMAL,
		 const string * original_string = NULL);
  ptr_op_t parse(string& str, const flags_t flags = EXPR_PARSE_NORMAL) {
    std::istringstream stream(str);
    return parse(stream, flags, &str);
  }
};

} // namespace ledger

#endif // _PARSER_H

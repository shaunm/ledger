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

#include "option.h"

namespace ledger {

namespace {
  typedef tuple<expr_t::ptr_op_t, bool> op_bool_tuple;

  op_bool_tuple find_option(scope_t& scope, const string& name)
  {
    char buf[128];
    std::strcpy(buf, "opt_");
    char * p = &buf[4];
    foreach (char ch, name) {
      if (ch == '-')
	*p++ = '_';
      else
	*p++ = ch;
    }
    *p = '\0';

    expr_t::ptr_op_t op = scope.lookup(buf);
    if (op)
      return op_bool_tuple(op, false);

    *p++ = '_';
    *p = '\0';

    return op_bool_tuple(scope.lookup(buf), true);
  }

  op_bool_tuple find_option(scope_t& scope, const char letter)
  {
    char buf[10];
    std::strcpy(buf, "opt_");
    buf[4] = letter;
    buf[5] = '\0';

    expr_t::ptr_op_t op = scope.lookup(buf);
    if (op)
      return op_bool_tuple(op, false);

    buf[5] = '_';
    buf[6] = '\0';

    return op_bool_tuple(scope.lookup(buf), true);
  }

  void process_option(const function_t& opt, scope_t& scope,
		      const char * arg)
  {
    try {
      call_scope_t args(scope);
      if (arg)
	args.push_back(string_value(arg));

      opt(args);
    }
    catch (const std::exception& err) {
#if 0
      add_error_context("While parsing option '--" << opt->long_opt
			<< "'" << (opt->short_opt != '\0' ?
				   (string(" (-") + opt->short_opt + "):") :
				   ": "));
#endif
      throw;
    }
  }
}

void process_option(const string& name, scope_t& scope,
		    const char * arg)
{
  op_bool_tuple opt(find_option(scope, name));
  if (opt.get<0>())
    process_option(opt.get<0>()->as_function(), scope, arg);
}

void process_environment(const char ** envp, const string& tag,
			 scope_t& scope)
{
  const char * tag_p   = tag.c_str();
  unsigned int tag_len = tag.length();

  for (const char ** p = envp; *p; p++)
    if (! tag_p || std::strncmp(*p, tag_p, tag_len) == 0) {
      char   buf[128];
      char * r = buf;
      const char * q;
      for (q = *p + tag_len;
	   *q && *q != '=' && r - buf < 128;
	   q++)
	if (*q == '_')
	  *r++ = '-';
	else
	  *r++ = std::tolower(*q);
      *r = '\0';

      if (*q == '=') {
	try {
	  process_option(string(buf), scope, q + 1);
	}
	catch (const std::exception& err) {
	  add_error_context("While parsing environment variable option '"
			    << *p << "':");
	  throw;
	}
      }
    }
}

void process_arguments(int, char ** argv, const bool anywhere,
		       scope_t& scope, std::list<string>& args)
{
  for (char ** i = argv; *i; i++) {
    if ((*i)[0] != '-') {
      if (anywhere) {
	args.push_back(*i);
	continue;
      } else {
	for (; *i; i++)
	  args.push_back(*i);
	break;
      }
    }

    // --long-option or -s
    if ((*i)[1] == '-') {
      if ((*i)[2] == '\0')
	break;

      char * name  = *i + 2;
      char * value = NULL;
      if (char * p = std::strchr(name, '=')) {
	*p++ = '\0';
	value = p;
      }

      op_bool_tuple opt(find_option(scope, name));
      if (! opt.get<0>())
	throw_(option_error, "illegal option --" << name);

      if (opt.get<1>() && value == NULL) {
	value = *++i;
	if (value == NULL)
	  throw_(option_error, "missing option argument for --" << name);
      }
      process_option(opt.get<0>()->as_function(), scope, value);
    }
    else if ((*i)[1] == '\0') {
      throw_(option_error, "illegal option -");
    }
    else {
      typedef tuple<expr_t::ptr_op_t, bool, char> op_bool_char_tuple;

      std::list<op_bool_char_tuple> option_queue;

      int x = 1;
      for (char c = (*i)[x]; c != '\0'; x++, c = (*i)[x]) {
	op_bool_tuple opt(find_option(scope, c));
	if (! opt.get<0>())
	  throw_(option_error, "illegal option -" << c);

	option_queue.push_back
	  (op_bool_char_tuple(opt.get<0>(), opt.get<1>(), c));
      }

      foreach (op_bool_char_tuple& o, option_queue) {
	char * value = NULL;
	if (o.get<1>()) {
	  value = *++i;
	  if (value == NULL)
	    throw_(option_error,
		   "missing option argument for -" << o.get<2>());
	}
	process_option(o.get<0>()->as_function(), scope, value);
      }
    }
  }
}

} // namespace ledger

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

#include "format.h"
#include "account.h"
#include "parser.h"

namespace ledger {

format_t::elision_style_t
     format_t::elision_style = ABBREVIATE;
int  format_t::abbrev_length = 2;

bool format_t::ansi_codes    = false;
bool format_t::ansi_invert   = false;

void format_t::element_t::dump(std::ostream& out) const
{
  out << "Element: ";

  switch (type) {
  case STRING: out << " STRING"; break;
  case EXPR:   out << "   EXPR"; break;
  }

  out << "  flags: " << flags();
  out << "  min: ";
  out << std::right;
  out.width(2);
  out << int(min_width);
  out << "  max: ";
  out << std::right;
  out.width(2);
  out << int(max_width);

  switch (type) {
  case STRING: out << "   str: '" << chars << "'" << std::endl; break;
  case EXPR:   out << "  expr: "   << expr << std::endl; break;
  }
}

namespace {
  string partial_account_name(account_t& account)
  {
    string name;

    for (account_t * acct = &account;
	 acct && acct->parent;
	 acct = acct->parent) {
      if (acct->has_xdata() &&
	  acct->xdata().has_flags(ACCOUNT_EXT_DISPLAYED))
	break;

      if (name.empty())
	name = acct->name;
      else
	name = acct->name + ":" + name;
    }

    return name;
  }
}

format_t::element_t * format_t::parse_elements(const string& fmt)
{
  std::auto_ptr<element_t> result;

  element_t * current = NULL;

  char   buf[1024];
  char * q = buf;

  // The following format codes need to be implemented as functions:
  //
  //   d: COMPLETE_DATE_STRING
  //   D: DATE_STRING
  //   S: SOURCE; break
  //   B: ENTRY_BEG_POS
  //   b: ENTRY_BEG_LINE
  //   E: ENTRY_END_POS
  //   e: ENTRY_END_LINE
  //   X: CLEARED
  //   Y: ENTRY_CLEARED
  //   C: CODE
  //   P: PAYEE
  //   W: OPT_ACCOUNT
  //   a: ACCOUNT_NAME
  //   A: ACCOUNT_FULLNAME
  //   t: AMOUNT
  //   o: OPT_AMOUNT
  //   T: TOTAL
  //   N: NOTE
  //   n: OPT_NOTE
  //   _: DEPTH_SPACER
  //   
  //   xB: XACT_BEG_POS
  //   xb: XACT_BEG_LINE
  //   xE: XACT_END_POS
  //   xe: XACT_END_LINE

  for (const char * p = fmt.c_str(); *p; p++) {
    if (*p != '%' && *p != '\\') {
      *q++ = *p;
      continue;
    }

    if (! result.get()) {
      result.reset(new element_t);
      current = result.get();
    } else {
      current->next.reset(new element_t);
      current = current->next.get();
    }

    if (q != buf) {
      current->type  = element_t::STRING;
      current->chars = string(buf, q);
      q = buf;

      current->next.reset(new element_t);
      current = current->next.get();
    }

    if (*p == '\\') {
      p++;
      current->type = element_t::STRING;
      switch (*p) {
      case 'b': current->chars = "\b"; break;
      case 'f': current->chars = "\f"; break;
      case 'n': current->chars = "\n"; break;
      case 'r': current->chars = "\r"; break;
      case 't': current->chars = "\t"; break;
      case 'v': current->chars = "\v"; break;
      case '\\': current->chars = "\\"; break;
      default: current->chars = string(1, *p); break;
      }
      continue;
    }

    ++p;
    while (*p == '!' || *p == '-') {
      switch (*p) {
      case '-':
	current->add_flags(ELEMENT_ALIGN_LEFT);
	break;
      case '!':
	current->add_flags(ELEMENT_FORMATTED);
	break;
      }
      ++p;
    }

    int num = 0;
    while (*p && std::isdigit(*p)) {
      num *= 10;
      num += *p++ - '0';
    }
    current->min_width = num;

    if (*p == '.') {
      ++p;
      num = 0;
      while (*p && std::isdigit(*p)) {
	num *= 10;
	num += *p++ - '0';
      }
      current->max_width = num;
      if (current->min_width == 0)
	current->min_width = current->max_width;
    }

    switch (*p) {
    case '%':
      current->type  = element_t::STRING;
      current->chars = "%";
      break;

    case '|':
      current->type  = element_t::STRING;
      current->chars = " ";
      break;

    case '(':
    case '[': {
      std::istringstream str(p);
      current->type = element_t::EXPR;
      string temp(p);
      current->expr.parse(str, EXPR_PARSE_SINGLE, &temp);
      if (str.eof()) {
	current->expr.set_text(p);
	p += std::strlen(p);
      } else {
	assert(str.good());
	istream_pos_type pos = str.tellg();
	current->expr.set_text(string(p, p + long(pos)));
	p += long(pos) - 1;

	// Don't gobble up any whitespace
	const char * base = p;
	while (p >= base && std::isspace(*p))
	  p--;
      }
      break;
    }

    default: {
      current->type  = element_t::EXPR;
      char buf[2];
      buf[0] = *p;
      buf[1] = '\0';
      current->chars = buf;
      current->expr.parse(buf);
      break;
    }
    }
  }

  if (q != buf) {
    if (! result.get()) {
      result.reset(new element_t);
      current = result.get();
    } else {
      current->next.reset(new element_t);
      current = current->next.get();
    }
    current->type  = element_t::STRING;
    current->chars = string(buf, q);
  }

  return result.release();
}

namespace {
  inline void mark_plain(std::ostream& out) {
    out << "\e[0m";
  }
}

void format_t::format(std::ostream& out_str, scope_t& scope)
{
  for (element_t * elem = elements.get(); elem; elem = elem->next.get()) {
    std::ostringstream out;
    string name;

    if (elem->has_flags(ELEMENT_ALIGN_LEFT))
      out << std::left;
    else
      out << std::right;

    if (elem->min_width > 0)
      out.width(elem->min_width);

    switch (elem->type) {
    case element_t::STRING:
      out << elem->chars;
      break;

    case element_t::EXPR:
      try {
	elem->expr.compile(scope);

	value_t value;
	if (elem->expr.is_function()) {
	  call_scope_t args(scope);
	  args.push_back(long(elem->max_width));
	  value = elem->expr.get_function()(args);
	} else {
	  value = elem->expr.calc(scope);
	}
	DEBUG("format.expr", "value = (" << value << ")");
	value.strip_annotations().dump(out, elem->min_width);
      }
      catch (const calc_error&) {
	out << (string("%") + elem->chars);
      }
      break;

    default:
      assert(false);
      break;
    }

    string temp = out.str();

    DEBUG("format.expr", "output = \"" << temp << "\"");

    if (! elem->has_flags(ELEMENT_FORMATTED) &&
	elem->max_width > 0 && elem->max_width < temp.length())
      out_str << truncate(temp, elem->max_width);
    else
      out_str << temp;
  }
}

string format_t::truncate(const string& str, unsigned int width,
			  const bool is_account)
{
  const unsigned int len = str.length();
  if (len <= width)
    return str;

  assert(width < 4095);

  char buf[4096];

  switch (elision_style) {
  case TRUNCATE_LEADING:
    // This method truncates at the beginning.
    std::strncpy(buf, str.c_str() + (len - width), width);
    buf[0] = '.';
    buf[1] = '.';
    break;

  case TRUNCATE_MIDDLE:
    // This method truncates in the middle.
    std::strncpy(buf, str.c_str(), width / 2);
    std::strncpy(buf + width / 2,
		 str.c_str() + (len - (width / 2 + width % 2)),
		 width / 2 + width % 2);
    buf[width / 2 - 1] = '.';
    buf[width / 2] = '.';
    break;

  case ABBREVIATE:
    if (is_account) {
      std::list<string> parts;
      string::size_type beg = 0;
      for (string::size_type pos = str.find(':');
	   pos != string::npos;
	   beg = pos + 1, pos = str.find(':', beg))
	parts.push_back(string(str, beg, pos - beg));
      parts.push_back(string(str, beg));

      string result;
      unsigned int newlen = len;
      for (std::list<string>::iterator i = parts.begin();
	   i != parts.end();
	   i++) {
	// Don't contract the last element
	std::list<string>::iterator x = i;
	if (++x == parts.end()) {
	  result += *i;
	  break;
	}

	if (newlen > width) {
	  result += string(*i, 0, abbrev_length);
	  result += ":";
	  newlen -= (*i).length() - abbrev_length;
	} else {
	  result += *i;
	  result += ":";
	}
      }

      if (newlen > width) {
	// Even abbreviated its too big to show the last account, so
	// abbreviate all but the last and truncate at the beginning.
	std::strncpy(buf, result.c_str() + (result.length() - width), width);
	buf[0] = '.';
	buf[1] = '.';
      } else {
	std::strcpy(buf, result.c_str());
      }
      break;
    }
    // fall through...

  case TRUNCATE_TRAILING:
    // This method truncates at the end (the default).
    std::strncpy(buf, str.c_str(), width - 2);
    buf[width - 2] = '.';
    buf[width - 1] = '.';
    break;
  }
  buf[width] = '\0';

  return buf;
}

} // namespace ledger

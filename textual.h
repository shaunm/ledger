#ifndef _TEXTUAL_H
#define _TEXTUAL_H

#include "parser.h"

namespace ledger {

class textual_parser_t : public parser_t
{
 public:
  virtual bool test(std::istream& in) const {
    return true;
  }

  virtual unsigned int parse(std::istream&	 in,
			     journal_t *	 journal,
			     account_t *	 master        = NULL,
			     const std::string * original_file = NULL);
};

} // namespace ledger

#endif // _TEXTUAL_H
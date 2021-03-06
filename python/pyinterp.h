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

#ifndef _PYINTERP_H
#define _PYINTERP_H

#include "scope.h"

#include <boost/python.hpp>
#include <Python.h>

namespace ledger {

class python_interpreter_t : public noncopyable, public scope_t
{
  boost::python::handle<> mmodule;

  python_interpreter_t();

public:
  boost::python::dict nspace;

  python_interpreter_t(scope_t& parent);

  virtual ~python_interpreter_t() {
    TRACE_DTOR(python_interpreter_t);

    Py_Finalize();
  }

  boost::python::object import(const string& name);

  enum py_eval_mode_t {
    PY_EVAL_EXPR,
    PY_EVAL_STMT,
    PY_EVAL_MULTI
  };

  boost::python::object eval(std::istream& in,
			     py_eval_mode_t mode = PY_EVAL_EXPR);
  boost::python::object eval(const string& str,
			     py_eval_mode_t mode = PY_EVAL_EXPR);
  boost::python::object eval(const char * c_str,
			     py_eval_mode_t mode = PY_EVAL_EXPR) {
    string str(c_str);
    return eval(str, mode);
  }

  class functor_t {
    functor_t();
  protected:
    boost::python::object func;
  public:
    functor_t(const string&, boost::python::object _func) : func(_func) {
      TRACE_CTOR(functor_t, "const string&, boost::python::object");
    }
    functor_t(const functor_t& other) : func(other.func) {
      TRACE_CTOR(functor_t, "copy");
    }
    virtual ~functor_t() throw() {
      TRACE_DTOR(functor_t);
    }
    virtual value_t operator()(call_scope_t& args);
  };

  virtual expr_t::ptr_op_t lookup(const string& name) {
    if (boost::python::object func = eval(name))
      return WRAP_FUNCTOR(functor_t(name, func));
    return expr_t::ptr_op_t();
  }

  class lambda_t : public functor_t {
    lambda_t();
  public:
    lambda_t(boost::python::object code) : functor_t("<lambda>", code) {
      TRACE_CTOR(functor_t, "boost::python::object");
    }
    lambda_t(const lambda_t& other) : functor_t(other) {
      TRACE_CTOR(lambda_t, "copy");
    }
    virtual ~lambda_t() throw() {
      TRACE_DTOR(lambda_t);
    }
    virtual value_t operator()(call_scope_t& args);
  };
};

} // namespace ledger

#endif // _PYINTERP_H

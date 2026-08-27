// Copyright 2026, Google Inc.
// All rights reserved.
//
// C++11/C++1y compatibility polyfills for GoogleTest v1.16.
//
// Upstream v1.16 requires C++14.  Platforms that must stay on C++11 (or that
// can use the C++14 draft via -std=c++1y) can include this header to supply
// the handful of C++14 library features the library depends on.
//
// Prefer -std=c++1y (or -std=c++14) on the compiler when available; this
// header is the fallback for strict C++11 toolchains.

#ifndef GOOGLETEST_INCLUDE_GTEST_INTERNAL_GTEST_CPP11_COMPAT_H_
#define GOOGLETEST_INCLUDE_GTEST_INTERNAL_GTEST_CPP11_COMPAT_H_

#include <cstddef>
#include <memory>
#include <type_traits>
#include <utility>

// Only provide polyfills when the language mode is below C++14.
#if !defined(GTEST_INTERNAL_CPLUSPLUS_LANG) || \
    GTEST_INTERNAL_CPLUSPLUS_LANG < 201402L

namespace std {

// enable_if_t, decay_t, and make_unique may already be provided by YOU-i
// YiPredefCXX11.h on C++11 platform builds; skip to avoid std redefinition.
#ifndef _YI_PREDEF_CXX11_H_

template <bool B, class T = void>
using enable_if_t = typename enable_if<B, T>::type;

template <typename T>
using decay_t = typename decay<T>::type;

// Non-array objects (C++14 make_unique).
template <typename T, typename... Args>
typename enable_if<!is_array<T>::value, unique_ptr<T>>::type make_unique(
    Args&&... args) {
  return unique_ptr<T>(new T(std::forward<Args>(args)...));
}

// Unbounded arrays: make_unique<T[]>(size).
template <typename T>
typename enable_if<is_array<T>::value && extent<T>::value == 0,
                   unique_ptr<T>>::type make_unique(size_t size) {
  typedef typename remove_extent<T>::type element_type;
  return unique_ptr<T>(new element_type[size]());
}

#endif  // !_YI_PREDEF_CXX11_H_

// C++14 type aliases not covered by YiPredefCXX11.h.
template <bool B, class T, class F>
using conditional_t = typename conditional<B, T, F>::type;

template <typename T>
using remove_cv_t = typename remove_cv<T>::type;

template <typename T>
using remove_const_t = typename remove_const<T>::type;

template <typename T>
using remove_reference_t = typename remove_reference<T>::type;

// C++14 std::index_sequence and friends (backported from GoogleTest v1.12).
template <size_t... Is>
struct index_sequence {
  using type = index_sequence;
};

template <size_t... Is>
struct integer_sequence {
  using value_type = size_t;
};

template <bool plus_one, typename T, size_t sizeofT>
struct _gtest_double_sequence;

template <size_t... I, size_t sizeofT>
struct _gtest_double_sequence<true, index_sequence<I...>, sizeofT> {
  using type = index_sequence<I..., (sizeofT + I)..., 2 * sizeofT>;
};

template <size_t... I, size_t sizeofT>
struct _gtest_double_sequence<false, index_sequence<I...>, sizeofT> {
  using type = index_sequence<I..., (sizeofT + I)...>;
};

template <size_t N>
struct _gtest_make_index_sequence_impl
    : _gtest_double_sequence<N % 2 == 1,
                              typename _gtest_make_index_sequence_impl<N / 2>::type,
                              N / 2>::type {};

template <>
struct _gtest_make_index_sequence_impl<0> : index_sequence<> {};

template <size_t N>
using make_index_sequence = typename _gtest_make_index_sequence_impl<N>::type;

template <typename... T>
using index_sequence_for = make_index_sequence<sizeof...(T)>;

// GCC 4.x libstdc++ lacks is_trivially_copy_constructible but already provides
// is_trivially_destructible; only polyfill the missing trait.
#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 5)
template <typename T>
struct is_trivially_copy_constructible
    : integral_constant<
          bool, has_trivial_copy_constructor<
                    typename remove_reference<T>::type>::value> {};
#endif

}  // namespace std

#define GTEST_NEEDS_CPP11_POLYFILLS 1

// Heterogeneous comparison functors (replaces C++14 transparent std::equal_to<>
// etc. used by polymorphic matchers).
namespace testing {
namespace internal {

struct AnyEq {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a == b;
  }
};
struct AnyNe {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a != b;
  }
};
struct AnyLt {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a < b;
  }
};
struct AnyGt {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a > b;
  }
};
struct AnyLe {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a <= b;
  }
};
struct AnyGe {
  template <typename A, typename B>
  bool operator()(const A& a, const B& b) const {
    return a >= b;
  }
};

}  // namespace internal
}  // namespace testing

#else  // C++14 and above — native standard library features are available.

#define GTEST_NEEDS_CPP11_POLYFILLS 0

#endif  // GTEST_INTERNAL_CPLUSPLUS_LANG < 201402L

#endif  // GOOGLETEST_INCLUDE_GTEST_INTERNAL_GTEST_CPP11_COMPAT_H_

/* Non-Negagive Least Squares Algorithm for Eigen.
 *
 * Copyright (C) 2013 Hannes Matuschek, hmatuschek at uni-potsdam.de
 *
 * This Source Code Form is subject to the terms of the Mozilla
 * Public License v. 2.0. If a copy of the MPL was not distributed
 * with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/** \defgroup nnls Non-Negative Least Squares (NNLS) Module
 * This module provides a single class @c Eigen::NNLS implementing the NNLS algorithm.
 * The algorithm is described in "SOLVING LEAST SQUARES PROBLEMS", by Charles L. Lawson and
 * Richard J. Hanson, Prentice-Hall, 1974 and solves optimization problems of the form
 *
 * \f[ \min \left\Vert Ax-b\right\Vert_2^2\quad s.t.\, x\ge 0\,.\f]
 *
 * The algorithm solves the constrained least quares (LS) problem above by subsequently solving a
 * subset of the problem called passiv set, i.e. \f$\left\Vert A^Px^P-b\right\Vert_2^2\f$,
 * where \f$A^P\f$ is a matrix formed by selecting all columns of A which are in the passive set
 * \f$P\f$. */

#ifdef EIGEN3_NNLS_DEBUG
#include <iostream>
#endif

#ifndef __EIGEN_NNLS_H__
#define __EIGEN_NNLS_H__


namespace Eigen {

/** \ingroup nnls
 * \class NNLS
 * \brief Implementation of the Non-Negative Least Squares (NNLS) algorithm.
 * \param MatrixType The type of the system matrix \f$A\f$.
 *
 * This class implements the NNLS algorithm as described in "SOLVING LEAST SQUARES PROBLEMS",
 * Charles L. Lawson and Richard J. Hanson, Prentice-Hall, 1974. This algorithm solves a least
 * squares problem iteratively and ensures that the solution is non-negative. I.e.
 *
 * \f[ \min \left\Vert Ax-b\right\Vert_2^2\quad s.t.\, x\ge 0 \f]
 *
 * \note Please note that it is possible to construct a NNLS problem for which the algorithm does
 *       not converge. In "nature" these cases are extremely rare. However, you can specify the
 *       maximum number of iterations with the constructor to avoid endless loops.
 * \todo Restrict the scalar type to real floating point types. */
template <class _MatrixType> class NNLS
{
public:
  typedef _MatrixType MatrixType;

  enum {
    RowsAtCompileTime = MatrixType::RowsAtCompileTime,
    ColsAtCompileTime = MatrixType::ColsAtCompileTime,
    Options = MatrixType::Options,
    MaxRowsAtCompileTime = MatrixType::MaxRowsAtCompileTime,
    MaxColsAtCompileTime = MatrixType::MaxColsAtCompileTime
  };

  typedef typename MatrixType::Scalar Scalar;
  typedef typename MatrixType::RealScalar RealScalar;
  typedef typename MatrixType::Index Index;
  typedef Matrix<Scalar, ColsAtCompileTime, ColsAtCompileTime> MatrixAtAType;
  /** Type of a row vector of the system matrix \f$A\f$. */
  typedef Matrix<Scalar, ColsAtCompileTime, 1> RowVectorType;
  /** Type of a column vector of the system matrix \f$A\f$. */
  typedef Matrix<Scalar, RowsAtCompileTime, 1> ColVectorType;
  typedef PermutationMatrix<ColsAtCompileTime, ColsAtCompileTime, Index> PermutationType;
  typedef typename PermutationType::IndicesType IndicesType;


  /** Defines the possible heuristic to choose the next parameter for the system update.
   * Currently there is only one, @c MAX_DESCENT, which chooses the one with the largest
   * gradient. */
  typedef enum {
    MAX_DESCENT ///< Choose the one with the largest gradient.
  } Heuristic;


  /** \brief Constructs a NNLS sovler and initializes it with the given system matrix @c A.
   * \param A Specifies the system matrix.
   * \param max_iter Specifies the maximum number of iterations to solve the system, if
   *        @c max_iter<0 tere is no limit and the algorithm will only return on convergence.
   * \param eps Specifies the precision of the optimum. */
  NNLS(const MatrixType &A, int max_iter=-1, Scalar eps=1e-10)
    : _max_iter(max_iter), _num_ls(0), _epsilon(eps),
      _A(A), _AtA(_A.cols(), _A.cols()),
      _x(_A.cols()), _w(_A.cols()), _y(_A.cols()),
      _P(_A.cols()), _QR(_A.rows(), _A.cols()), _qrCoeffs(_A.cols()), _tempVector(_A.cols())
  {
    // Precompute A^T*A
    _AtA = A.transpose() * A;
  }


  /** \brief Solves the NNLS problem.
   * The dimension of @c b must be equal to the number of rows of @c A, given to the constructor
   * (of cause). Returns @c true on success and @c false otherwise. The solution can be obtained
   * by the @c x method. */
  bool solve(const ColVectorType &b, Heuristic heuristic=MAX_DESCENT);

  /** \brief Retruns the solution if a problem was solved.
   * If not, an uninitialized vector may be returned. */
  inline const RowVectorType &x() const { return _x; }

  /** \brief Returns the number of LS problems needed to be solved to converge. */
  inline size_t numLS() const { return _num_ls; }

  /** \brief Solves the NNLS problem
   *         \f$ \min \left\Vert Ax-b\right\Vert_2^2\quad s.t.\, x\ge 0 \f$.
   * Returns @c true on success and @c false otherwise. The result is stored in @c x on exit. */
  static inline bool
  solve(const MatrixType &A, const ColVectorType &b, RowVectorType &x,
        int max_iter=-1, typename MatrixType::Scalar eps=1e-10)
  {
    NNLS<MatrixType> nnls(A, max_iter, eps);
    if (! nnls.solve(b)) { return false; }
    x.noalias() = nnls.x();
    return true;
  }


protected:
  /** Searches for the index in Z with the largest value of @c v
   *  (\f$argmax v^P\f$) . */
  Index _argmax_Z(const RowVectorType &v) {
    const IndicesType &idxs = _P.indices();
    Index m_idx = _Np; Scalar m = v(idxs(m_idx));
    for (Index i=(_Np+1); i<_A.cols(); i++) {
      Index idx = idxs(i);
      if (m < v(idx)) { m = v(idx); m_idx = i; }
    }
    return m_idx;
  }


  /** Searches for the largest value in \f$v^Z\f$. */
  Scalar _max_Z(const RowVectorType &v) {
    const IndicesType &idxs = _P.indices();
    Scalar m = v(idxs(_Np));
    for (Index i=(_Np+1); i<_A.cols(); i++) {
      Index idx = idxs(i);
      if (m < v(idx)) { m = v(idx);}
    }
    return m;
  }


  /** Searches for the smallest value in \f$v^P\f$. */
  Scalar _min_P(const RowVectorType &v) {
    eigen_assert(_Np > 0);
    const IndicesType &idxs = _P.indices();
    Scalar m = v(idxs(0));
    for (Index i=1; i<_Np; i++) {
      Index idx = idxs(i);
      if (m > v(idx)) { m = v(idx); }
    }
    return m;
  }


  /** Adds the given index @c idx to the set P and updates the QR decomposition of \f$A^P\f$. */
  void _addToP(Index idx);

  /** Removes the given index idx from the set P and updates the QR decomposition of \f$A^P\f$. */
  void _remFromP(Index idx);

  /** Solves the LS problem \f$\left\Vert y-A^Px\right\Vert_2^2\f$. */
  void _solveLS_P(const ColVectorType &b);

  /** Updates the gradient \c _w using the current partial solution \c _x. */
  void _updateGradient() {
    // w <- A^T b - A^TA x
    _w = _Atb - _AtA*_x;
#ifdef EIGEN3_NNLS_DEBUG
    std::cerr << "NNLS(): Gradient at (" << _x.transpose()
              << ") = (" << _w.transpose() << ")" << std::endl;
#endif
  }


protected:
  /** Holds the maximum number of iterations for the NNLS algorithm, @c -1 means that there is no
   * limit. */
  int _max_iter;
  /** Holds the number of iterations. */
  int _num_ls;
  /** Size of the P (passive) set. */
  Index _Np;
  /** Accuracy of the algorithm w.r.t the optimality of the solution (gradient). */
  Scalar _epsilon;
  /** The system matrix, a copy of the one given to the constructor. */
  MatrixType _A;
  /** Precomputed product \f$A^TA\f$. */
  MatrixAtAType _AtA;
  /** Will hold the solution. */
  RowVectorType _x;
  /** Will hold the current gradient. */
  RowVectorType _w;
  /** Will hold the partial solution. */
  RowVectorType _y;
  /** Precomputed product \f$A^Tb\f$. */
  RowVectorType _Atb;
  /** Holds the current permutation matrix, the first @c _Np columns form the set P and the rest
   * the set Z. */
  PermutationType _P;
  /** QR decomposition to solve the (passive) sub system (together with @c _qrCoeffs). */
  MatrixType _QR;
  /** QR decomposition to solve the (passive) sub system (together with @c _QR). */
  RowVectorType _qrCoeffs;
  /** Some workspace for QR decomposition. */
  RowVectorType _tempVector;
};



/* ********************************************************************************************
 * Implementation
 * ******************************************************************************************** */

namespace internal {

/** Basically a modified copy of @c Eigen::internal::householder_qr_inplace_unblocked that
 * performs a rank-1 update of the QR matrix in compact storage. This function assumes, that
 * the first @c k-1 columns of the matrix @c mat contain the QR decomposition of \f$A^P\f$ up to
 * column k-1. Then the QR decomposition of the k-th column (given by @c newColumn) is computed by
 * applying the k-1 Householder projectors on it and finally compute the projector \f$H_k\f$ of
 * it. On exit the matrix @c mat and the vector @c hCoeffs contain the QR decomposition of the
 * first k columns of \f$A^P\f$. */
template <typename MatrixQR, typename HCoeffs, typename VectorQR>
void nnls_householder_qr_inplace_update(MatrixQR& mat, HCoeffs &hCoeffs,
                                        const VectorQR &newColumn,
                                        typename MatrixQR::Index k,
                                        typename MatrixQR::Scalar* tempData = 0)
{
  typedef typename MatrixQR::Index Index;
  typedef typename MatrixQR::Scalar Scalar;
  typedef typename MatrixQR::RealScalar RealScalar;
  Index rows = mat.rows();

  eigen_assert(k < mat.cols());
  eigen_assert(k < rows);
  eigen_assert(hCoeffs.size() == mat.cols());
  eigen_assert(newColumn.size() == rows);

  Matrix<Scalar,Dynamic,1,ColMajor,MatrixQR::MaxColsAtCompileTime,1> tempVector;
  if(tempData == 0) {
    tempVector.resize(mat.cols());
    tempData = tempVector.data();
  }

  // Store new column in mat at column k
  mat.col(k) = newColumn;
  // Apply H = H_1...H_{k-1} on newColumn (skip if k=0)
  for (Index i=0; i<k; ++i) {
    Index remainingRows = rows - i;
    mat.col(k).tail(remainingRows).applyHouseholderOnTheLeft(
          mat.col(i).tail(remainingRows-1), hCoeffs.coeffRef(i), tempData+i+1);
  }
  // Construct Householder projector in-place in column k
  RealScalar beta;
  mat.col(k).tail(rows-k).makeHouseholderInPlace(hCoeffs.coeffRef(k), beta);
  mat.coeffRef(k,k) = beta;
}


/** Solves the system Ax=b, where A is given as its QR decomposition in the first @c rank columns
 * in @c mat. */
template <typename MatrixQR, typename HCoeffs, typename Dest>
void nnls_householder_qr_inplace_solve(const MatrixQR& mat, const HCoeffs &hCoeffs,
                                       Dest &c, typename MatrixQR::Index &rank)
{
  eigen_assert(mat.rows() == c.size());
  eigen_assert(mat.cols() == hCoeffs.size());
  eigen_assert(mat.cols() >= rank);

  c.applyOnTheLeft(householderSequence(
    mat.leftCols(rank),
    hCoeffs.head(rank)).transpose());

  mat.topLeftCorner(rank, rank)
     .template triangularView<Upper>()
     .solveInPlace(c.head(rank));
}
}


template<typename MatrixType>
bool NNLS<MatrixType>::solve(const ColVectorType &b, Heuristic heuristic)
{
#ifdef EIGEN3_NNLS_DEBUG
  std::cerr << "NNLS(): Start..." << std::endl;
  _QR.setZero(); _qrCoeffs.setZero();
#endif

  // Initialize solver
  _num_ls = 0; _x.setZero();

  // Together with _Np, P separates the space of coefficients into a active (Z) and passive (P)
  // set. The first _Np elements form the passive set P and the remaining elements form the
  // active set Z.
  _P.setIdentity(); _Np = 0;

  // Precompute A^T*b
  _Atb = _A.transpose() * b;

  // OUTER LOOP
  while (true)
  {
    // Update gradient _w
    _updateGradient();

    // Check if system is solved:
    if ((_A.cols()==_Np) || (_max_Z(_w)-_epsilon<0)) { return true; }

    switch (heuristic) {
    // find index of max descent and add it to P
    case MAX_DESCENT: _addToP(_argmax_Z(_w)); break;
    }

    // INNER LOOP
    while (true)
    {
      // Check if max. number of iterations is reached
      if ( (0 < _max_iter) && (int(_num_ls) >= _max_iter) ) {
        return false;
      }

      // Solve LS problem in P only, this step is rather trivial as _addToP & _remFromP
      // updates the QR decomposition of A^P.
      _solveLS_P(b);

      // Check feasability...
      bool feasable = true;
      Scalar alpha = std::numeric_limits<Scalar>::max(); Index remIdx;
      for (Index i=0; i<_Np; i++) {
        Index idx = _P.indices()(i);
        if (_y(idx) <= 0) {
          Scalar t = -_x(idx)/(_y(idx)-_x(idx));
          if (alpha > t) { alpha = t; remIdx = i; }
          feasable=false;
        }
      }
      // If solution is feasable, exit to outer loop
      if (feasable) { _x = _y; break; }

      // Infeasable solution -> interpolate to feasable one
      for (Index i=0; i<_Np; i++) {
        Index idx = _P.indices()(i);
        _x(idx) += alpha * (_y(idx) - _x(idx));
      }

      // Remove these indices from P and update QR decomposition
      _remFromP(remIdx);
    }
  }
}


template <typename MatrixType>
void NNLS<MatrixType>::_addToP(Index idx)
{
  // Update permutation matrix:
  IndicesType &idxs = _P.indices();
#ifdef EIGEN3_NNLS_DEBUG
  std::cerr << "NNLS(): Add index " << idxs(idx) << "@" << idx << " to passive set ("
            << _P.indices().head(_Np).transpose() << ")" << std::endl;
#endif

  std::swap(idxs(idx), idxs(_Np)); _Np++;

  // Perform rank-1 update of the QR decomposition stored in _QR & _qrCoeff
  internal::nnls_householder_qr_inplace_update(
        _QR, _qrCoeffs, _A.col(idxs(_Np-1)), _Np-1, _tempVector.data());
}


template <typename MatrixType>
void NNLS<MatrixType>::_remFromP(Index idx)
{
#ifdef EIGEN3_NNLS_DEBUG
  std::cerr << "NNLS(): Remove Idx " << _P.indices()(idx) << "@" << idx << " from passive set ("
            << _P.indices().head(_Np).transpose() << ")" << std::endl;
#endif
  // swap index with last passive one & reduce number of passive columns
  std::swap(_P.indices()(idx), _P.indices()(_Np-1)); _Np--;
  // Update QR decomposition starting from the removed index up to the end [idx, ..., _Np]
  for (Index i=idx; i<_Np; i++) {
    Index col = _P.indices()(i);
    internal::nnls_householder_qr_inplace_update(_QR, _qrCoeffs, _A.col(col), i, _tempVector.data());
  }
}


template <typename MatrixType>
void NNLS<MatrixType>::_solveLS_P(const ColVectorType &b)
{
  eigen_assert(_Np > 0);
  // Solve in permuted sub space
  ColVectorType tmp(b.rows()); tmp.noalias() = b;
  internal::nnls_householder_qr_inplace_solve(_QR, _qrCoeffs, tmp, _Np);
  _y.setZero();
  _y.head(_Np) = tmp.head(_Np);

#ifdef EIGEN3_NNLS_DEBUG
  HouseholderQR<Matrix<Scalar, Dynamic, Dynamic> > qr( (_A*_P).leftCols(_Np) );
  std::cerr << "NNLS(): Partial solution: (" << _y.head(_Np).transpose() <<
               "); True: (" << qr.solve(b).transpose() << ")" << std::endl;
#endif

  // Back permute y into original column order of A
  _y = _P*_y;

  // Increment LS counter
  _num_ls++;
}

}

#endif // __EIGEN_NNLS_H__

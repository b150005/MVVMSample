//
//  Model.swift
//  MVVMSample
//
//  Created by 伊藤 直輝 on 2022/03/27.
//

import Foundation
import RxSwift

/**
 `Model`は、UIに関係しないビジネスロジックを定義する。
 このとき、Modelをプロトコル化することでロジックを疎結合にしながら、テスト可能な設計にすることができる。(=Dependency Injection)
 また、RxSwiftで提供されている`Observable`型で返却することで、他のObservableオブジェクトと合成しやすくする。
 */
protocol ModelProtocol {
  func generateRandomInt(from x: Int, to y: Int) -> Observable<Int>
}

final class Model: ModelProtocol {
  /// 乱数を生成する
  /// - parameter from: 最小値
  /// - parameter to: 最大値
  /// - returns `x`以上`y`以下の整数値をもつイベントを発行する`Observable`
  func generateRandomInt(from x: Int, to y: Int) -> Observable<Int> {
    return Observable.just(Int.random(in: x...y))
  }
}

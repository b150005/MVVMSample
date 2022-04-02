//
//  ViewModel.swift
//  MVVMSample
//
//  Created by 伊藤 直輝 on 2022/03/27.
//

import Foundation
import RxSwift
import RxRelay

/**
 `ViewModel`は、UIに関係するモデルデータを定義する。
 */
final class ViewModel {
  // UIコンポーネントに表示するデータはObservableオブジェクトにしておく。
  let numBehaviorRelay: BehaviorRelay<String> = BehaviorRelay(value: "0")
  let buttonPublishSubject: PublishSubject<Void> = PublishSubject<Void>()
  
  // ViewModelはModelの処理を呼び出すため、プロパティとして保持しておく。
  // このとき、Modelのプロトコルに型定義しておくことで、ModelProtocolに準拠したあらゆるModelオブジェクトをスタブにできるようにしておく(=Dependency Injection)。
  // → Modelの処理をViewModelの初期化時でのみ呼び出す場合は、不要なプロパティとなるのを避けるためプロパティとして設定しないのが望ましい。
  private let model: ModelProtocol
  
  // データバインディングの必要性がなくなったタイミングでView(UIコンポーネント)のObservableオブジェクトの監視を停止するため、
  // DisposeBagインスタンスを保持しておく。
  private let disposeBag: DisposeBag = DisposeBag()
  
  // 初期化時にイベントを発火するUIコンポーネントのObservableを利用するため、パラメータに設定しておく。
  // → UIコンポーネントのObservableオブジェクトをViewModelのObservableプロパティに合わせるよう加工する。
  init(textFieldObservable: Observable<String?>, buttonObservable: Observable<Void>, model: ModelProtocol) {
    self.model = model
    
    // UIコンポーネント(View)のObservableを購読し、値を加工してViewModelのObservableオブジェクトのイベントとして発火させる。
    // → subscribe(onNext:onError:onCompleted:onDisposed:)メソッドでクロージャを用いる際は、
    //   クロージャからViewModelインスタンスへの参照を弱参照にすることで循環参照を避ける。
    disposeBag.insert(
      // Viewのテキストフィールド(UITextField)が発火するイベントの購読
      textFieldObservable.subscribe(onNext: { [weak self] (numText: String?) -> Void in
        guard let self = self else { return }
        guard let numText = numText else { return }
        
        // テキストフィールド(UITextField)に値が入力されていない場合はViewModelの値を更新しない
        if numText == "" { return }
        
        self.numBehaviorRelay.accept(numText)
      }),
      
      // Viewのボタン(UIButton)が発火するイベントの購読
      buttonPublishSubject.flatMap { () -> Observable<Int> in
        return self.model.generateRandomInt(from: 1, to: 100)
      }.subscribe(onNext: { [weak self] (num: Int) -> Void in
        guard let self = self else { return }
        
        self.numBehaviorRelay.accept(String(num))
      })
    )
  }
}

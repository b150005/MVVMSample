//
//  ViewController.swift
//  MVVMSample
//
//  Created by 伊藤 直輝 on 2022/03/27.
//

import UIKit
import RxSwift
import RxCocoa

/**
 MVVMアーキテクチャでは、`UIViewController`は`View`に属する。
 `UIViewController`(のサブクラス)は、各UIコンポーネントと`ViewModel`インスタンスを保持し、
 ViewModelの`Observable`(=`Subject`・`Relay`を含む)プロパティ ⇄ 各UIコンポーネント の単方向(`ViewModel` → `View`)または双方向のデータバインディングを行う。
 */
class ViewController: UIViewController {
  @IBOutlet private weak var label: UILabel!
  @IBOutlet private weak var textField: UITextField!
  @IBOutlet private weak var button: UIButton!
  
  // UIコンポーネントへの入力イベントをViewModelに伝搬させるため、
  // ViewModelのObservableプロパティにはイベントリスナとなるUIコンポーネントのObservableインスタンスを格納する。
  // ここで、ViewModelの初期化はviewDidLoad()メソッドが呼ばれる前に実行されないようlazyプロパティを付与しておく。
  // また、ViewModelはModelのメソッドを使用するため、Modelインスタンスを生成して格納する。
  private lazy var viewModel: ViewModel = ViewModel(
    textFieldObservable: textField.rx.text.asObservable(),
    buttonObservable: button.rx.tap.asObservable(),
    model: Model()
  )
  
  // データバインディングの必要性がなくなったタイミングでViewModelのObservableオブジェクトの監視を停止するため、
  // DisposeBagインスタンスを保持しておく。
  private let disposeBag: DisposeBag = DisposeBag()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    disposeBag.insert(
      // ViewModelのObservableプロパティ → Viewのラベル(UILabel) のデータバインディング(≒購読)
      viewModel.numBehaviorRelay.bind(to: label.rx.text),
      
      // ViewModelのObservableプロパティ → Viewのテキストフィールド(UITextField) のデータバインディング(≒購読)
      viewModel.numBehaviorRelay.bind(to: textField.rx.text),
      
      // Viewのボタン(UIButton) → ViewModelのObservableプロパティ のデータバインディング(≒購読)
      button.rx.tap.bind(to: viewModel.buttonPublishSubject)
    )
  }
}


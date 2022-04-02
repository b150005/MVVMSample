#  MVVM × RxSwift

**MVVM**は、**Cocoa MVC**アーキテクチャと同様**Presentation Domain Separation**の概念を根底としており、
**アプリケーションのUI(Presentation)**と**UIとは無関係な処理(Domain)**を分離することを目的としている。

例として、以下の機能を有するアプリケーションを作成する。

1. テキストフィールド(`UITextField`)に数字を入力するとラベル(`UILabel`)に即時反映される
2. ボタン(`UIButton`)をタップすると、1〜100の範囲内の乱数が生成され、ラベル(`UILabel`)に反映される
3. 2.のアクションによってラベルの値に変更が生じた場合はテキストフィールド(`UITextField`)の入力値も変更される

ここで、MVVMアーキテクチャにおける`Model`・`View`・`ViewModel`の役割は、以下の通りである。

|レイヤー|役割|
|---|---|
|Model|UIとは無関係のビジネスロジック|
|View|UIコンポーネントの描画|
|⇅|(View と ViewModelでデータバインディング)|
|ViewModel|UIに関係するプレゼンテーションロジック|

# Model

`Model`は、UIに関係しないビジネスロジックを定義する。
このとき、Modelをプロトコル化することでロジックを疎結合にしながら、テスト可能な設計にすることができる。(=Dependency Injection)
また、RxSwiftで提供されている`Observable`型で返却することで、他のObservableオブジェクトと合成しやすくする。

```swift
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
```

# ViewModel

`ViewModel`は、UIに関係するモデルデータを定義する。
`View`のUIコンポーネントのObservableオブジェクトを購読し、加工した値をもつイベントを`ViewModel`のObservableプロパティから発行する。
また、`Model`の処理を呼び出し、Modelによって返却されたObservableオブジェクトのイベントを契機として`ViewModel`のObservableプロパティの値を更新する。

```swift
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
```

# View

MVVMアーキテクチャでは、`UIViewController`は`View`に属する。
`UIViewController`(のサブクラス)は、各UIコンポーネントと`ViewModel`インスタンスを保持し、
ViewModelの`Observable`(=`Subject`・`Relay`を含む)プロパティ ⇄ 各UIコンポーネント の単方向(`ViewModel` → `View`)または双方向のデータバインディングを行う。

```swift
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
```

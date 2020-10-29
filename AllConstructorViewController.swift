//
//  AllConstructorViewController.swift
//  Profit
//
//  Created by Виктор Андреевич on 22.07.2020.
//  Copyright © 2020 Profit. All rights reserved.
//

import UIKit
import RealmSwift

enum AllConstructorDrawMode {
    case AllConstructorDrawModeLine
    case AllConstructorDrawModeBrokenLine
    case AllConstructorDrawModeSquare
    case AllConstructorDrawModeDeleteLine
    
    var value: String {
        switch self {
        case .AllConstructorDrawModeLine:
            return "Line"
        case .AllConstructorDrawModeBrokenLine:
            return "Broken Line"
        case .AllConstructorDrawModeSquare:
            return "Square"
        case .AllConstructorDrawModeDeleteLine:
            return "Delete Line"
        }
    }
    var rowIndex: Int {
        switch self {
        case .AllConstructorDrawModeLine:
            return 0
        case .AllConstructorDrawModeBrokenLine:
            return 1
        case .AllConstructorDrawModeSquare:
            return 2
        case .AllConstructorDrawModeDeleteLine:
            return 3
        }
    }
}

class AllConstructorViewController: UIViewController {
    private static let kOffset: CGFloat = 10.0
    private let kOffsetX: String = "AllConstructorViewControllerСontentOffsetXForHall"
    private let kOffsetY: String = "AllConstructorViewControllerСontentOffsetYForHall"
    private let kScale: String = "AllConstructorViewControllerScaleForHall"

    public static let kSizeImage: CGFloat = 80.0
    
    @IBOutlet var constructorTableView: ConstructorTableView!
    @IBOutlet var constructorScrollView: UIScrollView!
    private var constructorView: GridView = {
           let v = GridView()
           v.translatesAutoresizingMaskIntoConstraints = false
           return v
       }()

    @IBOutlet var hallsCollectionView: HallsCollectionView!

    @IBOutlet var hallCollectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet var hallCollectionBottomConstraint: NSLayoutConstraint!

    @IBOutlet var hallTableViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet var hallTableViewTrailingConstraint: NSLayoutConstraint!
    
    private var firstPoint: CGPoint?
    private var secondPoint: CGPoint?
    
    private var currentBorderWidth: Float = 1.0
    
    private var currentMode: AllConstructorDrawMode = .AllConstructorDrawModeLine {
        didSet {
            self.setupMode()
        }
    }
    
    private var currentHall: Hall?
    private var halls: [Hall] = [Hall]()
    private let modes = ["Line", "Broken Line", "Square", "Delete Line"]
    private var modePopoverButton: UIBarButtonItem?
    
    private var offsetPoint = CGPoint.init(x: AllConstructorViewController.kOffset,
                                           y: AllConstructorViewController.kOffset)
    
    private var hallObjectsByCurrentHall: [HallObject] = [HallObject]()
    private var hallBordersByCurrentHall: [BorderObject] = [BorderObject]()
    private var tableViewModelsByCurrentHall: [Int : TableViewModel] = [Int : TableViewModel]()

    private let currentUserDefaults = UserDefaults.standard
    private var currentKoefCommon: CGFloat = 0.2
    private var switchToDraw: UIBarButtonItem!
    private var isDraw = false
    private var isFitToScreen = false
    private var contentSize = CGSize.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.constructorScrollView.delegate = self
        self.constructorView.delegateGridView = self
        self.hallsCollectionView.delegateCollection = self
        self.constructorTableView.delegateTable = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupHallsCollectionView()
        if let hall = self.currentHall {
            self.setupDataByCurrentHall(hall: hall)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    //MARK: - Private Methods
    //MARK: Setup
    private func setupMinZoomScaleForSize(_ size: CGSize) {
        let widthScale = size.width / self.constructorScrollView.bounds.width
        let heightScale = size.height / self.constructorScrollView.bounds.height
        let maxScale = max(widthScale, heightScale)

        
        self.constructorScrollView.minimumZoomScale = 1
        self.constructorScrollView.maximumZoomScale = maxScale

        if let hall = self.currentHall {
            if let scale = self.currentUserDefaults.value(forKey: "\(self.kScale)\(hall.id)") as? CGFloat {
                self.constructorScrollView.setZoomScale(scale, animated: true)
            } else {
                self.constructorScrollView.setZoomScale(1, animated: true)
            }
            
            if let contentOffsetX = self.currentUserDefaults.value(forKey: "\(self.kOffsetX)\(hall.id)") as? CGFloat,
                let contentOffsetY = self.currentUserDefaults.value(forKey: "\(self.kOffsetY)\(hall.id)") as? CGFloat  {
                self.offsetPoint = CGPoint.init(x: contentOffsetX * (1/self.constructorScrollView.zoomScale) + AllConstructorViewController.kOffset,
                                                y: contentOffsetY * (1/self.constructorScrollView.zoomScale) + AllConstructorViewController.kOffset)
                self.constructorScrollView.setContentOffset(CGPoint.init(x: contentOffsetX,
                                                                         y: contentOffsetY),
                                                            animated: true)
            } else {
                self.constructorScrollView.setContentOffset(CGPoint.zero, animated: true)
                self.offsetPoint = CGPoint.init(x: AllConstructorViewController.kOffset,
                                                y: AllConstructorViewController.kOffset)
            }
        }
    }
    
    private func setupDataByCurrentHall(hall: Hall) {
        self.hallObjectsByCurrentHall = СonstructorManager.shared.getAllHallObjectsData(currentHallID: hall.id)//tempHallObjectsByCurrentHall
        self.constructorTableView.setupHallObjects(objects: self.hallObjectsByCurrentHall, currentHall: hall)
        self.setupTableViewConstraint(isShow: self.isShowTableView())
        
        self.constructorView.bordersDict = self.getBordersForGridView()
        self.constructorView.currentHallID = hall.id
        
        self.setupDefault()
        self.setupHallObjectsWithScale()
        self.setupNavigationBar()
    }
    
    private func setupDefault() {
        self.setupMode()

        self.constructorView.grid = GridView.kGrid
        
        self.constructorScrollView.isScrollEnabled = true
        self.constructorScrollView.showsVerticalScrollIndicator = true
        self.constructorScrollView.showsHorizontalScrollIndicator = true
        self.constructorScrollView.decelerationRate = UIScrollView.DecelerationRate.fast
    }
    //установка всех объектов зала и границ в зависимости от currentHall, а так же очистка предыдущих объектов со ScrollView
    private func setupHallObjectsWithScale() {
        self.tableViewModelsByCurrentHall = [:]
        self.contentSize = CGSize.init(width: ((self.view.frame.width - 20) * 4),
                                      height: self.constructorScrollView.bounds.height * 4)
        let koefCommon: CGFloat = max(koefW, koefH)
        self.constructorView.grid = GridView.kGrid / koefCommon
        
        for object in self.hallObjectsByCurrentHall {
            if !object.isInstalled {continue}
            guard let image = object.getImage() else {continue}
            
            let tableViewModel = TableViewModel.init(origin: CGPoint.init(x: CGFloat(object.x),
                                                                          y: CGFloat(object.y)),
                                                     image: image,
                                                     modelID: object.id,
                                                     size: CGSize.init(width: ConstructorViewController.kSizeImage/koefCommon,
                                                                       height: ConstructorViewController.kSizeImage/koefCommon),
                                                     angle: CGFloat(object.angle))
            
            tableViewModel.alpha = 0.0
            
            self.tableViewModelsByCurrentHall.updateValue(tableViewModel, forKey: tableViewModel.modelID)
            
            tableViewModel.delegateViewModel = self
            tableViewModel.isViewing = false
            tableViewModel.panGR.isEnabled = true
        }
        
        self.constructorView.setupModelViews(array: Array(self.tableViewModelsByCurrentHall.values))
        
        self.setupMinZoomScaleForSize(self.contentSize)
        self.setupContentSizeOfGrid()
    }

    private func setupNavigationBar() {
        self.navigationController?.navigationBar.topItem?.title = "Return"
        self.navigationItem.title = "Конструктор Залов"
        
        self.navigationItem.rightBarButtonItems = self.getButtonsForDraw(isDraw: false)
    }

    private func setupFrameInHallObject(tableModel: TableViewModel) {
        guard let hall = self.currentHall else {return}
        let optModel = self.hallObjectsByCurrentHall.filter{ $0.id == tableModel.modelID }.first
        guard let model = optModel else {return}
        
        try! realmDB.safeWrite({
            model.x = Float(tableModel.frame.origin.x)
            model.y = Float(tableModel.frame.origin.y)
            model.width = Float(tableModel.frame.width)
            model.height = Float(tableModel.frame.height)
            model.angle = Float(tableModel.angle)
            model.hallModelID = hall.id
            model.isInstalled = true
        })
        
        hall.changeScheme(changeObject: model, isDeleteObject: false)
    }
    //получение залов и настройка CollectionView
    private func setupHallsCollectionView() {
        self.halls = СonstructorManager.shared.getHallsData()

        self.setupCollectionConstraint(isShow: self.halls.count > 1)

        if self.halls.count > 0 {
            self.currentHall = self.currentHall == nil ? self.halls.first : self.currentHall
            self.hallsCollectionView.currentHall = self.currentHall
            self.hallsCollectionView.setupHalls(halls: self.halls)
        } else {
            APPDelegate.showAlert(title: "Have Not Halls", message: "")
        }
    }
    
    private func setupTableViewConstraint(isShow: Bool) {
        UIView.animate(withDuration: 1, animations: {
            self.hallTableViewWidthConstraint.constant = isShow ? 350 : 0
            self.hallTableViewTrailingConstraint.constant = isShow ? 10 : 0

            self.view.layoutIfNeeded()
        })
    }
    
    private func setupCollectionConstraint(isShow: Bool) {
        UIView.animate(withDuration: 1, animations: {
            self.hallCollectionHeightConstraint.constant = isShow ? 80 : 0
            self.hallCollectionBottomConstraint.constant = isShow ? 20 : 0
            
            self.view.layoutIfNeeded()
        })
    }
    
    private func setupContentSizeOfGrid() {
        let yOffset: CGFloat = 30 + self.hallsCollectionView.frame.height + 80
        let xOffset: CGFloat = 20
        
        self.constructorScrollView.addSubview(self.constructorView)
        let g = self.constructorScrollView.contentLayoutGuide
        
        NSLayoutConstraint.activate([
            self.constructorView.widthAnchor.constraint(equalToConstant: (self.view.frame.width - xOffset)),
            self.constructorView.heightAnchor.constraint(equalToConstant: (self.view.frame.height - yOffset)),
            self.constructorView.topAnchor.constraint(equalTo: g.topAnchor, constant: 0.0),
            self.constructorView.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: 0.0),
            self.constructorView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 0.0),
            self.constructorView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: 0.0),
        ])

        self.constructorView.draw(CGRect.init(origin: self.constructorView.frame.origin,
                                              size: CGSize.init(width: (self.view.frame.width - xOffset),
                                                                height: (self.view.frame.height - yOffset))))
    }
    
    private func setupMode() {
        self.constructorView.isDrawBrokenLine = false
        self.constructorView.isDrawSquareLine = false
        self.constructorView.isDrawLine = false
        self.constructorView.isDelete = false

        if self.isDraw {
            switch self.currentMode {
            case .AllConstructorDrawModeLine:
                self.constructorView.isDrawLine = true
            case .AllConstructorDrawModeBrokenLine:
                self.constructorView.isDrawBrokenLine = true
            case .AllConstructorDrawModeSquare:
                self.constructorView.isDrawSquareLine = true
            case .AllConstructorDrawModeDeleteLine:
                self.constructorView.isDelete = true
            }
        }
    }
    
    //MARK: - Getter
    private func isShowTableView() -> Bool {
        return self.hallObjectsByCurrentHall.filter({ $0.getImage() != nil }).count > 0
    }
    
    private func getBordersForGridView() -> [Int : [BorderObject]] {
        guard let hall = self.currentHall else {return [:]}
        var pointsDict = [Int : [BorderObject]]()
        
        self.hallBordersByCurrentHall = СonstructorManager.shared.getBordersData(currentHallID: hall.id).sorted(by: { $0.id < $1.id })
        
        for borderPoint in self.hallBordersByCurrentHall {
            if var array = pointsDict[borderPoint.id] {
                array.append(borderPoint)
                pointsDict.updateValue(array, forKey: borderPoint.id)
            } else {
                pointsDict.updateValue([borderPoint], forKey: borderPoint.id)
            }
        }
        
        return pointsDict
    }

    private func getButtonsForDraw(isDraw: Bool) -> [UIBarButtonItem] {
        var array = [UIBarButtonItem]()
        
        if isDraw {
            self.switchToDraw = UIBarButtonItem(title: "Off Draw",
                                                style: .plain,
                                                target: self,
                                                action: #selector(switchToDrawAction))
            self.switchToDraw.tintColor = UIColor.red
        } else {
            self.switchToDraw = UIBarButtonItem(title: "On Draw",
                                                style: .plain,
                                                target: self,
                                                action: #selector(switchToDrawAction))
        }
        
        array.append(self.switchToDraw)
                
        let fullSize = UIBarButtonItem(title: "Full Size",
                                                       style: .plain,
                                                       target: self,
                                                       action: #selector(fullSizeAction))
        array.append(fullSize)
        
        let fitToScreen = UIBarButtonItem(title: "Fit To Screen",
                                                       style: .plain,
                                                       target: self,
                                                       action: #selector(fitToScreenAction))
        fitToScreen.title = self.isFitToScreen ? "Show Table" : "Fit To Screen"
        
        if self.isShowTableView() {
            array.append(fitToScreen)
        }
        
        if isDraw {
            self.modePopoverButton = UIBarButtonItem(title: self.currentMode.value,
                                                     style: .plain,
                                                     target: self,
                                                     action: #selector(openPopoverItemsForDrawAction))
            self.modePopoverButton!.possibleTitles = Set(self.modes)
            
            let setupBorderWidth = UIBarButtonItem(title: "Setup Border Width",
                                                   style: .plain,
                                                   target: self,
                                                   action: #selector(setupBorderWidthAction))
            
            array.append(setupBorderWidth)
            array.append(self.modePopoverButton!)
        }
        
        return array
    }
    
    //MARK: - Actions
    @objc private func fitToScreenAction(button: UIBarButtonItem) {
        self.isFitToScreen = !self.isFitToScreen
        button.title = self.isFitToScreen ? "Show Table" : "Fit To Screen"
        
        self.setupTableViewConstraint(isShow: !self.isFitToScreen)
        self.setupContentSizeOfGrid()
    }
    
    @objc private func fullSizeAction() {
        self.constructorScrollView.setZoomScale(1, animated: true)
    }
    
    @objc private func setupBorderWidthAction() {
        let alert = UIAlertController(title: "", message: "Здесь Вы можете ввести необходимую ширину линий", preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = "Текущая ширина линий: \(self.currentBorderWidth)"
            textField.keyboardType = .numberPad
            textField.delegate = self
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .destructive, handler: {(_) in
        }))

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (_) in
            guard let self = self else {return}
            guard let textField: UITextField = alert.textFields?[0] else {return}
            guard let text = textField.text else {return}
            
            if text.count > 0 {
                self.currentBorderWidth = text.floatValue
                self.constructorView.currentBorderWidth = CGFloat(self.currentBorderWidth)
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc private func openPopoverItemsForDrawAction(sender: UIBarButtonItem) {
        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopoverTableViewController") as? PopoverTableViewController else {return}
        
        popVC.modalPresentationStyle = .popover
        
        let popoverVC = popVC.popoverPresentationController
        let buttonItemView = sender.value(forKey: "view") as? UIView

        popoverVC?.delegate = self
        popoverVC?.sourceView = buttonItemView
        popoverVC?.sourceRect = buttonItemView?.frame ?? CGRect.zero
        popVC.preferredContentSize = CGSize.init(width: 250, height: 250)

        popVC.modes = self.modes
        popVC.selectedMode = self.currentMode.rowIndex
        popVC.delegatePopoverVC = self
        
        self.present(popVC, animated: true, completion: nil)
    }
    
    @objc private func switchToDrawAction() {
        self.isDraw = !self.isDraw
        self.constructorScrollView.isScrollEnabled = true//!self.isDraw
        self.constructorView.isDrawLine = self.isDraw//
        self.constructorView.currentBorderWidth = CGFloat(self.currentBorderWidth)
        self.currentMode = .AllConstructorDrawModeLine
        self.navigationItem.rightBarButtonItems = self.getButtonsForDraw(isDraw: self.isDraw)
    }
    
    @objc private func squareLine() {
        self.constructorView.isDrawBrokenLine = false
        self.constructorView.isDrawSquareLine = !self.constructorView.isDrawSquareLine
    }
    
    @objc private func brokenLine() {
        self.constructorView.isDrawBrokenLine = !self.constructorView.isDrawBrokenLine
    }
    
    @objc private func deleteLine() {
        self.constructorView.isDrawLine = self.constructorView.isDelete
        self.constructorView.isDrawBrokenLine = false
        self.constructorView.isDrawSquareLine = false
        self.constructorView.isDelete = !self.constructorView.isDelete
    }
    
    @objc private func setupTableViews() {}
}

//MARK: - HallsCollectionViewDelegate
extension AllConstructorViewController: HallsCollectionViewDelegate {
    func didSelect(hall: Hall) {
        self.currentHall = hall
        self.setupDataByCurrentHall(hall: hall)
    }
}

//MARK: - ConstructorTableViewDelegate
extension AllConstructorViewController: ConstructorTableViewDelegate {
    func removeModelToConstructor(model: HallObject) {
        guard let hall = self.currentHall else {return}
        guard let modelView = self.tableViewModelsByCurrentHall[model.id] else {return}

        СonstructorManager.shared.removeObjectHallFromDB(object: model, currentHall: hall)
        self.constructorView.removeTableView(tableView: modelView)

        if self.tableViewModelsByCurrentHall.containsValue(value: modelView) {
            self.tableViewModelsByCurrentHall.removeValue(forKey: modelView.modelID)
        }
    }
    
    func addModelToConstructor(model: HallObject, point: CGPoint) {
        guard let image = model.getImage() else {return}
        
        let koefCommon: CGFloat = max(koefW, koefH)
        let imageSize = CGSize.init(width: ConstructorViewController.kSizeImage / koefCommon,
                                    height: ConstructorViewController.kSizeImage / koefCommon)
                
        let pointY = point.y - imageSize.height + 15
        let imageView = UIImageView.init(frame: CGRect.init(origin: CGPoint.init(x: point.x, y: pointY),
                                                            size: imageSize))
        imageView.image = image

        self.constructorView.addSubview(imageView)

        UIView.animate(withDuration: 2, animations: {
            imageView.frame.origin = self.offsetPoint
        }, completion: { (completion) in
            if completion {
                let tableViewModel = TableViewModel.init(origin: self.offsetPoint,
                                                         image: image,
                                                         modelID: Int(model.id),
                                                         size: imageSize,
                                                         angle: CGFloat(model.angle))
                
                imageView.alpha = 0
                imageView.removeFromSuperview()
                
                self.constructorView.addModelView(modelView: tableViewModel)
                self.validationOffset(imageSize: imageSize)
                
                self.setupFrameInHallObject(tableModel: tableViewModel)
                
                tableViewModel.alpha = 1.0
                
                self.tableViewModelsByCurrentHall.updateValue(tableViewModel, forKey: tableViewModel.modelID)
                
                tableViewModel.delegateViewModel = self
                tableViewModel.isViewing = false
                tableViewModel.panGR.isEnabled = true
            }
        })
    }
    
    func didChangeAngleAtObjectToConstructor(model: HallObject) {
        let alert = UIAlertController(title: "", message: "Здесь Вы можете ввести необходимый угол", preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = "Текущий угол: \(model.angle)"
            textField.keyboardType = .decimalPad
            textField.delegate = self
        }

        alert.addAction(UIAlertAction(title: "Отмена", style: .destructive, handler: {(_) in
        }))

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (_) in
            guard let self = self else {return}
            guard let textField: UITextField = alert.textFields?[0] else {return}
            guard let text = textField.text else {return}
            
            if text.count > 0 {
                self.changeAngleInObject(object: model, angle: text.floatValue)
            }
        }))
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func changeAngleInObject(object: HallObject, angle: Float) {
        guard let hall = self.currentHall else {return}
        guard let modelView = self.tableViewModelsByCurrentHall[object.id] else {return}//self.tableViewModelsByCurrentHall.filter({ $0.modelID == object.id }).first else {return}
        
        UIView.animate(withDuration: 1) {
            modelView.imageView.transform = CGAffineTransform.init(rotationAngle: CGFloat(angle * .pi/180))
        }
        
        try! realmDB.safeWrite {
            object.angle = angle
        }
        
        hall.changeScheme(changeObject: object, isDeleteObject: false)
    }
    
    private func validationOffset(imageSize: CGSize) {
        var offsetY =  self.offsetPoint.y + imageSize.height + AllConstructorViewController.kOffset
        var offsetX = self.offsetPoint.x
        
        if offsetY > self.constructorScrollView.contentSize.height {
            offsetY = AllConstructorViewController.kOffset
            offsetX = self.offsetPoint.x + imageSize.width + AllConstructorViewController.kOffset
        }
        
        self.offsetPoint = CGPoint.init(x: offsetX, y: offsetY)
    }
}

//MARK: - UIPopoverPresentationControllerDelegate
extension AllConstructorViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

//MARK: - UITextFieldDelegate
extension AllConstructorViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard !string.isEmpty else {return true}

        if textField.keyboardType == .decimalPad {
            if !CharacterSet(charactersIn: "0123456789").isSuperset(of: CharacterSet(charactersIn: string)) {return false}
        }

        if textField.keyboardType == .numberPad {
            if range.location == 0 {
                if !CharacterSet(charactersIn: "123456789").isSuperset(of: CharacterSet(charactersIn: string)) {return false}
            } else {
                if !CharacterSet(charactersIn: "0123456789").isSuperset(of: CharacterSet(charactersIn: string)) {return false}
            }
        }

        return true
    }
}

//MARK: - TableViewModelDelegate
extension AllConstructorViewController: TableViewModelDelegate {
    func modelTouchesBegan(viewModel: TableViewModel) {
        performSegue(withIdentifier: ObjectInfoViewController.className,
                     sender: viewModel)
    }
    
    func modelTouchesEnded(viewModel: TableViewModel) {
        self.setupFrameInHallObject(tableModel: viewModel)
    }
}

//MARK: - GridViewDelegate
extension AllConstructorViewController: GridViewDelegate {
    func drawTouchesEnded(line: [CGPoint]) -> [BorderObject] {
        guard let hall = self.currentHall else {return []}
        var array = [BorderObject]()
        let maxLineID = СonstructorManager.shared.getCurrentLineID(currentHallID: hall.id) + 1
        
        for point in line {
            var border = realmDB.objects(BorderObject.self).filter{ $0.x == Float(point.x) && $0.y == Float(point.y) && $0.hallModelID == hall.id && $0.id == maxLineID }.first
            
            try! realmDB.safeWrite {
                if border == nil {
                    border = BorderObject()
                    if  let border = border {
                        realmDB.add(border)
                    }
                }
                if let border = border {
                    border.hallModelID = hall.id
                    border.x = Float(point.x)
                    border.y = Float(point.y)
                    border.id = maxLineID
                    border.widthBorder = self.currentBorderWidth == 0 ? 1 : self.currentBorderWidth
                    
                    array.append(border)
                }
            }
        }

        hall.changeScheme(borderObjects: array, isDeleteObject: false)
        
        return array
    }
    
    func willDeleteLineByTouch(completion: @escaping (_ isDelete: Bool) -> ()) {
        let alert = UIAlertController(title: "", message: "Вы уверенны, что хотите удалить границу?", preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: "Отмена",
                                      style: UIAlertAction.Style.destructive,
                                      handler: { _ in
                                        completion(false)
        }))
        alert.addAction(UIAlertAction(title: "Да, уверен",
                                      style: UIAlertAction.Style.default,
                                      handler: {(_: UIAlertAction!) in
                                        completion(true)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func deleteLineByTouch(lineID: Int) {
        guard let hall = self.currentHall else {return}
        
        let border = Array(realmDB.objects(BorderObject.self)).filter { $0.hallModelID == hall.id && $0.id == lineID }
        
        hall.changeScheme(borderObjects: border, isDeleteObject: true)
    }
    
    func drawTouchesBegan() {}
}

//MARK: - PopoverTableViewControllerDelegate
extension AllConstructorViewController: PopoverTableViewControllerDelegate {
    func didSelectMode(row: Int) {
        self.currentMode = self.getMode(index: row)
        self.modePopoverButton?.title = self.currentMode.value
        self.setupMode()
    }
    
    private func getMode(index: Int) -> AllConstructorDrawMode {
        switch index {
        case 0:
            return .AllConstructorDrawModeLine
        case 1:
            return .AllConstructorDrawModeBrokenLine
        case 2:
            return .AllConstructorDrawModeSquare
        case 3:
            return .AllConstructorDrawModeDeleteLine
        default:
            return .AllConstructorDrawModeLine
        }
    }
}

//MARK: - UIScrollViewDelegate
extension AllConstructorViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.constructorView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if let hall = self.currentHall {
            let point = self.validationContentOffset(x: scrollView.contentOffset.x,
                                                     y: scrollView.contentOffset.y,
                                                     scale: scrollView.zoomScale,
                                                     size: scrollView.bounds.size,
                                                     contentSize: scrollView.contentSize)
            
            self.offsetPoint = CGPoint.init(x: point.x  * (1/scale) + AllConstructorViewController.kOffset,
                                            y:  point.y  * (1/scale) + AllConstructorViewController.kOffset)
            
            self.currentUserDefaults.setValue(scale,
                                              forKey: "\(self.kScale)\(hall.id)")
            self.currentUserDefaults.setValue(point.x,
                                              forKey: "\(self.kOffsetX)\(hall.id)")
            self.currentUserDefaults.setValue(point.y,
                                              forKey: "\(self.kOffsetY)\(hall.id)")
            self.currentUserDefaults.synchronize()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let hall = self.currentHall {
            let point = self.validationContentOffset(x: scrollView.contentOffset.x,
                                                     y: scrollView.contentOffset.y,
                                                     scale: scrollView.zoomScale,
                                                     size: scrollView.bounds.size,
                                                     contentSize: scrollView.contentSize)
            
            self.offsetPoint = CGPoint.init(x: point.x  * (1/scrollView.zoomScale) + AllConstructorViewController.kOffset,
                                            y:  point.y  * (1/scrollView.zoomScale) + AllConstructorViewController.kOffset)

            self.currentUserDefaults.setValue(point.x,
                                              forKey: "\(self.kOffsetX)\(hall.id)")
            self.currentUserDefaults.setValue(point.y,
                                              forKey: "\(self.kOffsetY)\(hall.id)")
            self.currentUserDefaults.synchronize()
        }
    }
    
    private func validationContentOffset(x: CGFloat, y: CGFloat, scale: CGFloat, size: CGSize?, contentSize: CGSize?) -> CGPoint {
        var x = x
        var y = y
        
        if let size = size, let contentSize = contentSize {
            if (size.width + x) > contentSize.width {
                x = contentSize.width - size.width
            }
            if (size.height + y) > contentSize.height {
                y = contentSize.height - size.height
            }
        }
        
        return CGPoint.init(x: x < 0 ? 0 : x,
                            y: y < 0 ? 0 : y)
    }
}

//
//  IndicatorTypeView.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/22.
//

import UIKit
import Combine

struct KLineIndicatorListItem: Hashable {
    var selection: IndicatorSelection
    var title: String
}

final class IndicatorTypeView: UIView, UICollectionViewDelegate {
    
    private enum SectionItem: Hashable {
        case main(KLineIndicatorListItem)
        case separator
        case sub(KLineIndicatorListItem)
    }

    var drawIndicatorPublisher: AnyPublisher<(ChartSection, IndicatorSelection), Never> {
        drawPublisher.eraseToAnyPublisher()
    }
    
    var eraseIndicatorPublisher: AnyPublisher<(ChartSection, IndicatorSelection), Never> {
        erasePublisher.eraseToAnyPublisher()
    }
    
    var mainIndicators: [KLineIndicator] = [] { didSet { reloadData() } }
    var subIndicators: [KLineIndicator] = [] { didSet { reloadData() } }
    var mainCustomIndicators: [KLineIndicatorListItem] = [] { didSet { reloadData() } }
    var subCustomIndicators: [KLineIndicatorListItem] = [] { didSet { reloadData() } }
    
    private let drawPublisher = PassthroughSubject<(ChartSection, IndicatorSelection), Never>()
    private let erasePublisher = PassthroughSubject<(ChartSection, IndicatorSelection), Never>()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, SectionItem>!
    private var selectedMainIndicators = Set<IndicatorSelection>()
    private var selectedSubIndicators = Set<IndicatorSelection>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let layout = makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.allowsMultipleSelection = true
        collectionView.register(IndicatorCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.register(SeparatorCell.self, forCellWithReuseIdentifier: "separator")
        collectionView.delegate = self
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupIndicatorListDataSource()
        reloadData()
        addSubview(collectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeLayout() -> UICollectionViewLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        return UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, _ in
            if sectionIndex == 1 {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(1), heightDimension: .fractionalHeight(1))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            } else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(50), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(50), heightDimension: .fractionalHeight(1))
                let group: NSCollectionLayoutGroup = if #available(iOS 16, *) {
                    .horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 1)
                } else {
                    .horizontal(layoutSize: groupSize, subitem: item, count: 1)
                }
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 8, bottom: 0, trailing: 8)
                return section
            }
        }, configuration: config)
    }
    
    private func setupIndicatorListDataSource() {
        dataSource = .init(collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let .main(item), let .sub(item):
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? IndicatorCell else {
                    return UICollectionViewCell()
                }
                cell.label.text = item.title
                return cell
            case .separator:
                return collectionView.dequeueReusableCell(withReuseIdentifier: "separator", for: indexPath)
            }
        })
    }
    
    private func reloadData() {

        var snapshot = NSDiffableDataSourceSnapshot<Int, SectionItem>()
        snapshot.appendSections([0, 1, 2])
        snapshot.appendItems(mainItems.map({ .main($0) }), toSection: 0)
        snapshot.appendItems([.separator], toSection: 1)
        snapshot.appendItems(subItems.map({ .sub($0) }), toSection: 2)
        dataSource.apply(snapshot)
        applySelection(for: .mainChart)
        applySelection(for: .subChart)
    }
    
    func setSelectedIndicators(main: [KLineIndicator], sub: [KLineIndicator]) {
        setSelectedIndicators(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    func setSelectedIndicators(_ state: IndicatorSelectionState) {
        selectedMainIndicators = Set(state.main).intersection(Set(mainItems.map(\.selection)))
        selectedSubIndicators = Set(state.sub).intersection(Set(subItems.map(\.selection)))
        applySelection(for: .mainChart)
        applySelection(for: .subChart)
    }
    
    private func applySelection(for section: ChartSection) {
        guard let collectionView else { return }
        let sectionIndex = section == .mainChart ? 0 : 2
        let items = dataSource.snapshot().itemIdentifiers(inSection: sectionIndex)
        let selectedSet = section == .mainChart ? selectedMainIndicators : selectedSubIndicators
        for (idx, item) in items.enumerated() {
            switch (section, item) {
            case (.mainChart, .main(let item)):
                let indexPath = IndexPath(item: idx, section: sectionIndex)
                if selectedSet.contains(item.selection) {
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                } else {
                    collectionView.deselectItem(at: indexPath, animated: false)
                }
            case (.subChart, .sub(let item)):
                let indexPath = IndexPath(item: idx, section: sectionIndex)
                if selectedSet.contains(item.selection) {
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                } else {
                    collectionView.deselectItem(at: indexPath, animated: false)
                }
            default:
                continue
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        switch type {
        case let .main(item):
            selectedMainIndicators.insert(item.selection)
            drawPublisher.send((.mainChart, item.selection))
        case let .sub(item):
            selectedSubIndicators.insert(item.selection)
            drawPublisher.send((.subChart, item.selection))
        default: break
        }

    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        switch type {
        case let .main(item):
            selectedMainIndicators.remove(item.selection)
            erasePublisher.send((.mainChart, item.selection))
        case let .sub(item):
            selectedSubIndicators.remove(item.selection)
            erasePublisher.send((.subChart, item.selection))
        default: break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        if case .separator = type {
            return false
        }
        return true
    }

    var debugTitles: (main: [String], sub: [String]) {
        (mainItems.map(\.title), subItems.map(\.title))
    }

    private var mainItems: [KLineIndicatorListItem] {
        mainIndicators.map { KLineIndicatorListItem(selection: .builtIn($0), title: $0.rawValue) } + mainCustomIndicators
    }

    private var subItems: [KLineIndicatorListItem] {
        subIndicators.map { KLineIndicatorListItem(selection: .builtIn($0), title: $0.rawValue) } + subCustomIndicators
    }
}

private class IndicatorCell: UICollectionViewCell {
    
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray2
        label.textAlignment = .center
        label.lineBreakMode = .byClipping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isSelected: Bool {
        didSet {
            label.textColor = isSelected
            ? .label.withAlphaComponent(0.8)
            : .systemGray2
            label.font = isSelected
            ? .systemFont(ofSize: 12, weight: .medium)
            : .systemFont(ofSize: 12)
        }
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(width: UIView.noIntrinsicMetric, height: layoutAttributes.size.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .defaultLow,
            verticalFittingPriority: .required
        )
        attributes.size = CGSize(width: ceil(size.width), height: ceil(size.height))
        return attributes
    }
}

private class SeparatorCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let line = UIView()
        line.backgroundColor = .separator
        contentView.addSubview(line)
        line.snp.makeConstraints { make in
            make.width.equalTo(1)
            make.height.equalTo(11)
            make.center.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

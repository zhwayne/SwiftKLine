//
//  IndicatorTypeView.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/22.
//

import UIKit
import Combine

final class IndicatorTypeView: UIView, UICollectionViewDelegate {
    
    private enum SectionItem: Hashable {
        case main(Indicator)
        case separator
        case sub(Indicator)
    }

    var drawIndicatorPublisher: AnyPublisher<(ChartSection, Indicator), Never> {
        drawPublisher.eraseToAnyPublisher()
    }
    
    var eraseIndicatorPublisher: AnyPublisher<(ChartSection, Indicator), Never> {
        erasePublisher.eraseToAnyPublisher()
    }
    
    var mainIndicators: [Indicator] = [] { didSet { reloadData() } }
    var subIndicators: [Indicator] = [] { didSet { reloadData() } }
    
    private let drawPublisher = PassthroughSubject<(ChartSection, Indicator), Never>()
    private let erasePublisher = PassthroughSubject<(ChartSection, Indicator), Never>()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, SectionItem>!
    private var selectedMainIndicators = Set<Indicator>()
    private var selectedSubIndicators = Set<Indicator>()
    
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
            case let .main(type), let .sub(type):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! IndicatorCell
                cell.label.text = type.rawValue
                return cell
            case .separator:
                return collectionView.dequeueReusableCell(withReuseIdentifier: "separator", for: indexPath)
            }
        })
    }
    
    private func reloadData() {

        var snapshot = NSDiffableDataSourceSnapshot<Int, SectionItem>()
        snapshot.appendSections([0, 1, 2])
        snapshot.appendItems(mainIndicators.map({ .main($0) }), toSection: 0)
        snapshot.appendItems([.separator], toSection: 1)
        snapshot.appendItems(subIndicators.map({ .sub($0) }), toSection: 2)
        dataSource.apply(snapshot)
        applySelection(for: .mainChart)
        applySelection(for: .subChart)
    }
    
    func setSelectedIndicators(main: [Indicator], sub: [Indicator]) {
        selectedMainIndicators = Set(main).intersection(mainIndicators)
        selectedSubIndicators = Set(sub).intersection(subIndicators)
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
            case (.mainChart, .main(let indicator)):
                let indexPath = IndexPath(item: idx, section: sectionIndex)
                if selectedSet.contains(indicator) {
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                } else {
                    collectionView.deselectItem(at: indexPath, animated: false)
                }
            case (.subChart, .sub(let indicator)):
                let indexPath = IndexPath(item: idx, section: sectionIndex)
                if selectedSet.contains(indicator) {
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
        case let .main(type):
            selectedMainIndicators.insert(type)
            drawPublisher.send((.mainChart, type))
        case let .sub(type):
            selectedSubIndicators.insert(type)
            drawPublisher.send((.subChart, type))
        default: break
        }

    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        switch type {
        case let .main(type):
            selectedMainIndicators.remove(type)
            erasePublisher.send((.mainChart, type))
        case let .sub(type):
            selectedSubIndicators.remove(type)
            erasePublisher.send((.subChart, type))
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

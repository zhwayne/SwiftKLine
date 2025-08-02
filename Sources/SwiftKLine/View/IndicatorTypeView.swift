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
        // 配置主图指标
        var snapshot = NSDiffableDataSourceSnapshot<Int, SectionItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(mainIndicators.map({ .main($0) }), toSection: 0)
        dataSource.apply(snapshot)
        
        // 分割线
        snapshot.appendSections([1])
        snapshot.appendItems([.separator], toSection: 1)
        dataSource.apply(snapshot)
        
        // 配置副图指标
        snapshot.appendSections([2])
        snapshot.appendItems(subIndicators.map({ .sub($0) }), toSection: 2)
        dataSource.apply(snapshot)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        switch type {
        case let .main(type): drawPublisher.send((.mainChart, type))
        case let .sub(type): drawPublisher.send((.subChart, type))
        default: break
        }
        dataSource.apply(snapshot)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let type = snapshot.itemIdentifiers(inSection: indexPath.section)[indexPath.item]
        switch type {
        case let .main(type): erasePublisher.send((.mainChart, type))
        case let .sub(type): erasePublisher.send((.subChart, type))
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
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
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

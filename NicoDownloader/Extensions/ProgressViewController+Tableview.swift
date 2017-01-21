//
//  ProgressViewController+Tableview.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 21..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Cocoa

extension ProgressViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NumberCell = "NumberCellID"
        static let TitleCell = "TitleCellID"
        static let ProgressCell = "ProgressCellID"
        static let StatusCell = "StatusCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor optionalTableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = optionalTableColumn else {
            return nil
        }
        let item = items[row]
        
        switch tableColumn {
        case tableView.tableColumns[0]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.NumberCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = String(row)
                return cell
            }
        case tableView.tableColumns[1]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.TitleCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.name
                return cell
            }
        case tableView.tableColumns[2]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.ProgressCell, owner: nil) as? ProgressTableCellView {
                cell.progressIndicator.doubleValue = Double(item.progress)
                return cell
            }
        default:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.StatusCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.status.description
                return cell
            }
        }
        return nil
    }
}

extension ProgressViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
}

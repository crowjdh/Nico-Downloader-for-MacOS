//
//  CommentBurnerViewController+TableView.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 1..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Cocoa

extension CommentBurnerViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NumberCell = "NumberCellID"
        static let VideoCell = "VideoCellID"
        static let CommentFileName = "CommentFileNameID"
        static let ProgressCell = "ProgressCellID"
    }
    
    override func keyDown(with event: NSEvent) {
        let delete = event.charactersIgnoringModifiers == "\u{7F}"
        if delete, let selectedTableView = selectedTableView, selectedTableView.selectedRow >= 0 {
            selectedTableView.selectedRowIndexes.reversed().forEach{ idx in
                items.remove(at: idx)
                videosTableView.reloadData()
                filterTableView.reloadData()
            }
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }
        
        selectedTableView = tableView
    }
    
    func tableView(_ tableView: NSTableView, viewFor optionalTableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = optionalTableColumn, let isVideoTable = isVideoTable(tableView) else {
            return nil
        }
        if isVideoTable {
            return configVideoTableView(tableView, viewFor: tableColumn, row: row)
        } else {
            return configFilterTableView(tableView, viewFor: tableColumn, row: row)
        }
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
        pboard.declareTypes([NSPasteboard.PasteboardType.fileURL], owner: self)
        pboard.setData(data, forType: NSPasteboard.PasteboardType.fileURL)
        
        return true
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let data = info.draggingPasteboard.data(forType: NSPasteboard.PasteboardType.fileURL)!
        let toIdx = row
        guard let isVideoTable = isVideoTable(tableView),
            let fromIndexSet = NSKeyedUnarchiver.unarchiveObject(with: data) as? IndexSet,
            let startIdx = fromIndexSet.first, let endIdx = fromIndexSet.last,
            startIdx != toIdx else {
            return false
        }
        
        var movingURLs: [URL?] = []
        let retrieveURLs: (Int) -> Void = { idx in
            if isVideoTable {
                movingURLs.append(self.items[idx].videoFileURL)
                self.items[idx].videoFileURL = nil
            } else {
                movingURLs.append(self.items[idx].commentFileURL)
                self.items[idx].commentFileURL = nil
            }
        }
        
        let moveDown = startIdx < toIdx
        let indexRange = IndexSet(moveDown ? startIdx...toIdx : toIdx...endIdx)
        let indexSetToPush = indexRange.subtracting(fromIndexSet)
        
        if moveDown {
            indexSetToPush.forEach(retrieveURLs)
            fromIndexSet.forEach(retrieveURLs)
        } else {
            fromIndexSet.forEach(retrieveURLs)
            indexSetToPush.forEach(retrieveURLs)
        }
        
        indexRange.forEach { idx in
            if isVideoTable {
                items[idx].videoFileURL = movingURLs.removeFirst()
            } else {
                items[idx].commentFileURL = movingURLs.removeFirst()
            }
        }
        
        tableView.reloadData()
        return true
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return NSDragOperation.every
    }
    
    private func isVideoTable(_ tableView: NSTableView) -> Bool? {
        guard let tableId = tableView.identifier else {
            return nil
        }
        return tableId.rawValue == "VideoTableViewID"
    }
    
    private func configVideoTableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn, row: Int) -> NSView?  {
        let item = items[row]
        
        switch tableColumn {
        case tableView.tableColumns[0]:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.NumberCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = String(row)
                return cell
            }
        default:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.VideoCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.videoFileURL?.absoluteString.removingPercentEncoding ?? ""
                return cell
            }
        }
        return nil
    }
    
    private func configFilterTableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn, row: Int) -> NSView?  {
        let item = items[row]
        
        switch tableColumn {
        case tableView.tableColumns[0]:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.NumberCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = String(row)
                return cell
            }
        case tableView.tableColumns[1]:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.CommentFileName), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.commentFileURL?.absoluteString.removingPercentEncoding ?? ""
                return cell
            }
        default:
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.ProgressCell), owner: nil) as? ProgressTableCellView {
                cell.progressIndicator.doubleValue = item.filterProgress
                return cell
            }
        }
        return nil
    }
}

extension CommentBurnerViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
}

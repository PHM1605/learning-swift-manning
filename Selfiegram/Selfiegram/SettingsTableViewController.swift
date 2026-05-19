//
//  SettingsTableViewController.swift
//  Selfiegram
//
//  Created by Pham Hoang Minh on 19/5/26.
//

import UIKit

enum SettingsKey: String {
    case saveLocation
}

class SettingsTableViewController: UITableViewController {

    @IBOutlet weak var locationSwitch: UISwitch!
    
    @IBOutlet weak var reminderSwitch: UISwitch!
    
    @IBAction func locationSwitchToggled(_ sender: Any) {
        // {saveLocation: true/false}
        UserDefaults.standard.set(locationSwitch.isOn, forKey: SettingsKey.saveLocation.rawValue)
    }
    
    @IBAction func reminderSwitchToggled(_ sender: Any) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // change appearance of switch accordingly
        locationSwitch.isOn = UserDefaults.standard.bool(forKey: SettingsKey.saveLocation.rawValue)
    }
}

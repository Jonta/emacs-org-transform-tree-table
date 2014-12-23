;;; org-transform-tree-table.el --- Transform org-mode tree with properties to a table

;; Copyright © 2014 Johan Lindstrom
;;
;; Author: Johan Lindstrom <buzzwordninja not_this_bit@googlemail.com>
;; URL: https://github.com/jplindstrom/emacs-org-transform-tree-table
;; Version: 0.1
;; Keywords: org-mode table org-table tree csv convert

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;
;;; Commentary:
;;
;; Transform all of part of an org-mode outline and the properties to
;; a table format (org-table or CSV)
;;

;;
;;; Installation:
;;
;; Put in load-path and initialize with:
;;    (require 'org-transform-tree-table)
;;
;;

;;; Changes
;;
;; 2014-12-23 - 0.1




(require 'dash)
(require 's)



;; interactive defuns

;;;###autoload
(defun org-transform-tree/org-table-buffer-from-outline ()
  "Transform an org tree to an org-table and return a new buffer
with the table.

If the region is active, convert that part of the
tree. Otherwise, if point is on an org heading, convert that
heading and its subtree. Otherwise convert the buffer.

In the resulting table, row one is the column titles. The rest of
the rows are property values.

Column one is the outline heading, and the rest are the
properties in the order they first appear in the buffer.

However, all special properties (e.g. 'COLUMNS', '*_ALL') are
placed after all the user properties (i.e. whatever properties
the user has added to capture information)."
  (interactive)
  (ott/table-buffer-from-outline
   "-table.org"
   'ott/org-table/render-rows-cols)
  )

;;;###autoload
(defun org-transform-tree/csv-buffer-from-outline ()
  "Transform an org tree to CSV format and return a new buffer
with the table.

Except it's not comma separated. It's tab separated because with
all (non) 'standard' ways to escape ',' in CSV files... let's not
even go there.

If the region is active, convert that part of the
tree. Otherwise, if point is on an org heading, convert that
heading and its subtree. Otherwise convert the buffer.

In the resulting table, row one is the column titles. The rest of
the rows are property values.

Column one is the outline heading, and the rest are the
properties in the order they first appear in the buffer.

However, all special properties (e.g. 'COLUMNS', '*_ALL') are
placed after all the user properties (i.e. whatever properties
the user has added to capture information)."
  (interactive)
  (ott/table-buffer-from-outline
   ".csv"
   'ott/csv-table/render-rows-cols)
  )


;; Main

(defun ott/table-buffer-from-outline (type render-fun)
  "Convert an org tree to a table and return a new buffer with the table.

If the region is active, convert that part of the
tree. Otherwise, if point is on an org heading, convert that
subtree. Otherwise convert the buffer.

In the resulting table, row one is the column titles. The rest of
the rows are property values.

Column one is the outline heading, and the rest are the
properties in the order they first appear in the buffer.

However, all special properties (e.g. 'COLUMNS', '*_ALL') are
placed after all the user properties (i.e. whatever properties
the user has added to capture information)."
  (let* ((target-buffer
          (get-buffer-create (concat (buffer-name) type)) ;; Use the other one later
          ;; (create-file-buffer (concat (or (buffer-file-name) "new") type))
          )
         (rows-cols (ott/rows-cols-from-tree))
         )
    (with-current-buffer target-buffer
      (funcall render-fun rows-cols))

    target-buffer
    ))


;;;###autoload
(defun ott/rows-cols-from-tree ()
  "Return a list of rows, with a list of columns from the org
tree.

Row one is the column titles.

Column one is the outline heading, and the rest are the
properties as they appear in the buffer.

However, all special properties (e.g. 'COLUMNS', '*_ALL') are
placed after all the user properties (i.e. whatever property
keys/values the user is edi property keys/values the user is
editing."
  (interactive)
  (save-excursion
    (let* (
           (ordered-property-keys
            (ott/user-then-special-property-keys
             (ott/unique-propery-keys-in-buffer-order)))

           (col-title-values (cons "Heading" ordered-property-keys))

           (row-col-data-values
            (ott/row-col-property-values ordered-property-keys))
           )
      (cons
       col-title-values
       row-col-data-values)
      )
    )
  )

(defun ott/row-col-property-values (property-keys)
  "Return list of rows with a list of columns that are property
values for the PROPERTY-KEYS for each tree heading."
  (ott/map-entries
   (lambda ()
     (cons
      (ott/level-and-heading (org-heading-components)) ; Heading
      (ott/current-property-values-from-keys property-keys)))
   ))

(defun ott/active-scope ()
  "Return a scope modifier depending on whether the region is
active, or whether point is on a org heading, or not."
  (if (org-region-active-p) 'region
    (if (org-at-heading-p) 'tree
      nil))) ;; Entire buffer

(defun ott/map-entries (fun)
  "Run org-map-entries with FUN in the active scope"
    (org-map-entries fun nil (ott/active-scope)))

(defun ott/level-and-heading (heading-components)
  "Return the *** level and the heading text of
ORG-HEADING-COMPONENTS"
  (let ((level (nth 1 heading-components))
        (heading-text (nth 4 heading-components)))
    (concat (make-string level ?*) " " heading-text)))

(defun ott/current-property-values-from-keys (property-keys)
  "Return list of values (possibly nil) for each property in
PROPERTY-KEYS."
  (mapcar
   (lambda (key)
     (alist-value (org-entry-properties nil 'standard key) key))
   property-keys
   )
  )

(defun ott/unique-propery-keys-in-buffer-order ()
  "Return list of all unique property keys used in drawers. They
are in the order they appear in the buffer."
  (let* ((entries-keys
          (ott/map-entries
           (lambda () (mapcar 'car (org-entry-properties nil 'standard)))))
         (all-keys '())
         )
    (dolist (keys entries-keys)
      (dolist (key keys)
        (add-to-list 'all-keys key t)))

    ;; Not sure why this one appears here. Are there others?
    (-remove (lambda (x) (string= x "CATEGORY")) all-keys)
    )
  )

(defun ott/user-then-special-property-keys (property-keys)
  "Return list with items in PROPERTY-KEYS, but where all column
properties are first and all special properties are at the end.

Column properties are properties the user would normally enter.

Special properties are things like 'COLUMNS' or 'Someting_ALL',
which are instructions for org-mode. They should typically go at
the end and not mix with the actual data."
  (-flatten (-separate 'ott/org-is-col-property property-keys)))

(defun ott/org-is-col-property (key)
  "Is KEY a column / user-data level property?"
  (if (string= key "COLUMNS") nil
    (if (string-match "._ALL$" key) nil
      t)))



;; Render org table

(defun ott/org-table/render-rows-cols (rows-cols)
  "Insert an org-table with the ROWS-COLS."
    (erase-buffer) ;; JPL: remove later
    (org-mode)
    (--each rows-cols
      (ott/org-table/insert-values-as-table-row it))
  )

(defun ott/org-table/insert-values-as-table-row (col-values)
  "Insert escaped COL-VALUES using the org-table format."
  (insert "|")
  (dolist (value col-values)
    (insert (concat " " (ott/org-table/escape-value value) " |"))
    )
  (insert "\n")
  )

(defun ott/org-table/escape-value (value)
  "Return VALUE but suitable to put in a table value. Return an
empty string for nil values."
  (if value
      (replace-regexp-in-string "|" "\\\\vert{}" value)
    ""))



;; Render CSV table (tab separated)

(defun ott/csv-table/render-rows-cols (rows-cols)
  "Insert a CSV table with the ROWS-COLS."
    (erase-buffer) ;; JPL: remove later
    (--each rows-cols
      (ott/csv-table/insert-values-as-table-row it))
  )

(defun ott/csv-table/insert-values-as-table-row (col-values)
  "Insert escaped COL-VALUES using CSV format (tab separated)."
  (insert
   (s-join "\t" (mapcar 'ott/csv-table/escape-value col-values)))
  (insert "\n")
  )

(defun ott/csv-table/escape-value (value)
  "Return VALUE but suitable to put in a CSV file. Return an
empty string for nil values."
  (if value
      value
    ""))



;; Test

(set-buffer "tree1.org")
(org-transform-tree/org-table-buffer-from-outline)



(provide 'org-transform-tree-table)

;;; org-transform-tree-table.el ends here
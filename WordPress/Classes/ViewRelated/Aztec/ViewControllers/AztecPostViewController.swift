import Foundation
import UIKit
import Aztec
import CocoaLumberjack
import Gridicons
import WordPressShared
import AFNetworking
import WPMediaPicker
import SVProgressHUD
import WordPressComAnalytics
import AVKit


// MARK: - Aztec's Native Editor!
//
class AztecPostViewController: UIViewController, PostEditor {

    /// Closure to be executed when the editor gets closed
    ///
    var onClose: ((_ changesSaved: Bool) -> ())?


    /// Indicates if Aztec was launched for Photo Posting
    ///
    var isOpenedDirectlyForPhotoPost = false


    /// Format Bar
    ///
    fileprivate(set) lazy var formatBar: Aztec.FormatBar = {
        return self.createToolbar()
    }()


    /// Aztec's Awesomeness
    ///
    fileprivate(set) lazy var richTextView: Aztec.TextView = {
        let textView = Aztec.TextView(defaultFont: Fonts.regular, defaultMissingImage: Assets.defaultMissingImage)

        let accessibilityLabel = NSLocalizedString("Rich Content", comment: "Post Rich content")
        self.configureDefaultProperties(for: textView, accessibilityLabel: accessibilityLabel)

        textView.delegate = self
        textView.formattingDelegate = self
        textView.textAttachmentDelegate = self
        textView.backgroundColor = Colors.aztecBackground

        return textView
    }()


    /// Aztec's Text Placeholder
    ///
    fileprivate(set) lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Share your story here...", comment: "Aztec's Text Placeholder")
        label.textColor = Colors.placeholder
        label.font = Fonts.regular
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()


    /// Raw HTML Editor
    ///
    fileprivate(set) lazy var htmlTextView: UITextView = {
        let storage = HTMLStorage(defaultFont: Fonts.regular)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()

        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let textView = UITextView(frame: .zero, textContainer: container)

        let accessibilityLabel = NSLocalizedString("HTML Content", comment: "Post HTML content")
        self.configureDefaultProperties(for: textView, accessibilityLabel: accessibilityLabel)

        textView.isHidden = true
        textView.delegate = self
        textView.accessibilityIdentifier = "HTMLContentView"
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none

        return textView

    }()


    /// Title's UITextView
    ///
    fileprivate(set) lazy var titleTextField: UITextView = {
        let textField = UITextView()

        textField.accessibilityLabel = NSLocalizedString("Title", comment: "Post title")
        textField.delegate = self
        textField.font = Fonts.title
        textField.returnKeyType = .next
        textField.textColor = UIColor.darkText
        textField.typingAttributes = [NSForegroundColorAttributeName: UIColor.darkText, NSFontAttributeName: Fonts.title]
        textField.translatesAutoresizingMaskIntoConstraints = false

        textField.isScrollEnabled = false
        textField.backgroundColor = .clear

        return textField
    }()


    /// Placeholder Label
    ///
    fileprivate(set) lazy var titlePlaceholderLabel: UILabel = {
        let placeholderText = NSLocalizedString("Title", comment: "Placeholder for the post title.")
        let titlePlaceholderLabel = UILabel()

        let attributes = [NSForegroundColorAttributeName: Colors.title, NSFontAttributeName: Fonts.title]
        titlePlaceholderLabel.attributedText = NSAttributedString(string: placeholderText, attributes: attributes)
        titlePlaceholderLabel.sizeToFit()
        titlePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false

        return titlePlaceholderLabel
    }()


    /// Title's Height Constraint
    ///
    fileprivate var titleHeightConstraint: NSLayoutConstraint!


    /// Title's Top Constraint
    ///
    fileprivate var titleTopConstraint: NSLayoutConstraint!


    /// Placeholder's Top Constraint
    ///
    fileprivate var textPlaceholderTopConstraint: NSLayoutConstraint!


    /// Separator View
    ///
    fileprivate(set) lazy var separatorView: UIView = {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 1))

        v.backgroundColor = Colors.separator
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()


    /// Negative Offset BarButtonItem: Used to fine tune navigationBar Items
    ///
    fileprivate lazy var separatorButtonItem: UIBarButtonItem = {
        let separator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        separator.width = Constants.separatorButtonWidth
        return separator
    }()


    /// NavigationBar's Close Button
    ///
    fileprivate lazy var closeBarButtonItem: UIBarButtonItem = {
        let cancelItem = UIBarButtonItem(customView: self.closeButton)
        cancelItem.accessibilityLabel = NSLocalizedString("Close", comment: "Action button to close edior and cancel changes or insertion of post")
        return cancelItem
    }()


    /// NavigationBar's Blog Picker Button
    ///
    fileprivate lazy var blogPickerBarButtonItem: UIBarButtonItem = {
        let pickerItem = UIBarButtonItem(customView: self.blogPickerButton)
        pickerItem.accessibilityLabel = NSLocalizedString("Switch Blog", comment: "Action button to switch the blog to which you'll be posting")
        return pickerItem
    }()


    /// Publish Button
    fileprivate(set) lazy var publishButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: self.postEditorStateContext.publishButtonText, style: WPStyleGuide.barButtonStyleForDone(), target: self, action: #selector(publishButtonTapped(sender:)))
        button.isEnabled = self.postEditorStateContext.isPublishButtonEnabled

        return button
    }()


    /// NavigationBar's More Button
    ///
    fileprivate lazy var moreBarButtonItem: UIBarButtonItem = {
        let image = Gridicon.iconOfType(.ellipsis)
        let moreItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(moreWasPressed))
        moreItem.accessibilityLabel = NSLocalizedString("More", comment: "Action button to display more available options")
        return moreItem
    }()


    /// Dismiss Button
    ///
    fileprivate lazy var closeButton: WPButtonForNavigationBar = {
        let cancelButton = WPStyleGuide.buttonForBar(with: Assets.closeButtonModalImage, target: self, selector: #selector(closeWasPressed))
        cancelButton.leftSpacing = Constants.cancelButtonPadding.left
        cancelButton.rightSpacing = Constants.cancelButtonPadding.right

        return cancelButton
    }()


    /// Blog Picker's Button
    ///
    fileprivate lazy var blogPickerButton: WPBlogSelectorButton = {
        let button = WPBlogSelectorButton(frame: .zero, buttonStyle: .typeSingleLine)
        button.addTarget(self, action: #selector(blogPickerWasPressed), for: .touchUpInside)
        return button
    }()


    /// Active Editor's Mode
    ///
    fileprivate(set) var mode = EditionMode.richText {
        didSet {
            switch mode {
            case .html:
                switchToHTML()
            case .richText:
                switchToRichText()
            }
        }
    }


    /// Post being currently edited
    ///
    fileprivate(set) var post: AbstractPost {
        didSet {
            removeObservers(fromPost: oldValue)
            addObservers(toPost: post)

            postEditorStateContext = nil
            refreshInterface()
        }
    }


    /// Active Downloads
    ///
    fileprivate var activeMediaRequests = [AFImageDownloadReceipt]()


    /// Boolean indicating whether the post should be removed whenever the changes are discarded, or not.
    ///
    fileprivate var shouldRemovePostOnDismiss = false


    /// Media Library Data Source
    ///
    fileprivate lazy var mediaLibraryDataSource: WPAndDeviceMediaLibraryDataSource = {
        return WPAndDeviceMediaLibraryDataSource(post: self.post)
    }()


    /// Media Progress Coordinator
    ///
    fileprivate lazy var mediaProgressCoordinator: MediaProgressCoordinator = {
        let coordinator = MediaProgressCoordinator()
        coordinator.delegate = self
        return coordinator
    }()


    /// Media Progress View
    ///
    fileprivate lazy var mediaProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.backgroundColor = Colors.progressBackground
        progressView.progressTintColor = Colors.progressTint
        progressView.trackTintColor = Colors.progressTrack
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()


    /// Selected Text Attachment
    ///
    fileprivate var currentSelectedAttachment: ImageAttachment?


    /// Last Interface Element that was a First Responder
    ///
    fileprivate var lastFirstResponder: UIView?


    /// Maintainer of state for editor - like for post button
    ///
    fileprivate lazy var postEditorStateContext: PostEditorStateContext! = {
        var originalPostStatus: BasePost.Status? = nil

        if let originalPost = self.post.original,
            let postStatus = originalPost.status,
            originalPost.hasRemote() {
            originalPostStatus = postStatus
        }


        // Self-hosted non-Jetpack blogs have no capabilities, so we'll default
        // to showing Publish Now instead of Submit for Review.
        let userCanPublish = self.post.blog.capabilities != nil ? self.post.blog.isPublishingPostsAllowed() : true
        let context = PostEditorStateContext(originalPostStatus: originalPostStatus, userCanPublish: userCanPublish, publishDate: self.post.dateCreated, delegate: self)

        return context
    }()


    /// Options
    ///
    fileprivate var optionsViewController: OptionsTableViewController!


    /// HTML Pre Processors
    ///
    fileprivate var htmlPreProcessors = [Processor]()


    /// HTML Post Processors
    ///
    fileprivate var htmlPostProcessors = [Processor]()


    // MARK: - Initializers

    required init(post: AbstractPost) {
        self.post = post

        super.init(nibName: nil, bundle: nil)

        self.restorationIdentifier = Restoration.restorationIdentifier
        self.restorationClass = type(of: self)
        self.shouldRemovePostOnDismiss = post.shouldRemoveOnDismiss

        addObservers(toPost: post)
    }

    required init?(coder aDecoder: NSCoder) {
        preconditionFailure("Aztec Post View Controller must be initialized by code")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        removeObservers(fromPost: post)

        cancelAllPendingMediaRequests()
    }


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: Fix the warnings triggered by this one!
        WPFontManager.loadNotoFontFamily()

        registerAttachmentImageProviders()
        registerHTMLProcessors()
        createRevisionOfPost()

        // Setup
        configureNavigationBar()
        configureView()
        configureSubviews()

        // Register HTML Processors for WordPress shortcodes

        // UI elements might get their properties reset when the view is effectively loaded. Refresh it all!
        refreshInterface()

        // Setup Autolayout
        view.setNeedsUpdateConstraints()

        configureMediaAppearance()

        if isOpenedDirectlyForPhotoPost {
            presentMediaPicker(animated: false)
        }
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configureDismissButton()
        startListeningToNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        restoreFirstResponder()

        // Handles refreshing controls with state context after options screen is dismissed
        editorContentWasUpdated()
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopListeningToNotifications()
        rememberFirstResponder()
    }


    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.resizeBlogPickerButton()
        })

        dismissOptionsViewControllerIfNecessary()
    }


    // MARK: - Title and Title placeholder position methods

    func updateTitlePosition() {
        let referenceView: UITextView = mode == .richText ? richTextView : htmlTextView
        titleTopConstraint.constant = -(referenceView.contentOffset.y+referenceView.contentInset.top)

        var contentInset = referenceView.contentInset
        contentInset.top = (titleHeightConstraint.constant + separatorView.frame.height)
        referenceView.contentInset = contentInset

        textPlaceholderTopConstraint.constant = referenceView.textContainerInset.top + referenceView.contentInset.top
    }

    func updateTitleHeight() {
        let referenceView: UITextView = mode == .richText ? richTextView : htmlTextView

        let sizeThatShouldFitTheContent = titleTextField.sizeThatFits(CGSize(width:view.frame.width - ( 2 * Constants.defaultMargin), height: CGFloat.greatestFiniteMagnitude))
        let insets = titleTextField.textContainerInset
        titleHeightConstraint.constant = max(sizeThatShouldFitTheContent.height, titleTextField.font!.lineHeight + insets.top + insets.bottom)

        textPlaceholderTopConstraint.constant = referenceView.textContainerInset.top + referenceView.contentInset.top

        var contentInset = referenceView.contentInset
        contentInset.top = (titleHeightConstraint.constant + separatorView.frame.height)
        referenceView.contentInset = contentInset
        referenceView.setContentOffset(CGPoint(x:0, y: -contentInset.top), animated: false)
    }


    // MARK: - Configuration Methods

    override func updateViewConstraints() {

        super.updateViewConstraints()

        let defaultMargin = Constants.defaultMargin

        titleHeightConstraint = titleTextField.heightAnchor.constraint(equalToConstant: titleTextField.font!.lineHeight)
        titleTopConstraint = titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: -richTextView.contentOffset.y)
        textPlaceholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: richTextView.topAnchor, constant: richTextView.textContainerInset.top + richTextView.contentInset.top)
        updateTitleHeight()

        NSLayoutConstraint.activate([
            titleTextField.leftAnchor.constraint(equalTo: view.leftAnchor, constant: defaultMargin),
            titleTextField.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -defaultMargin),
            titleTopConstraint,
            titleHeightConstraint
            ])

        let insets = titleTextField.textContainerInset
        NSLayoutConstraint.activate([
            titlePlaceholderLabel.leftAnchor.constraint(equalTo: titleTextField.leftAnchor, constant: insets.left + titleTextField.textContainer.lineFragmentPadding),
            titlePlaceholderLabel.rightAnchor.constraint(equalTo: titleTextField.rightAnchor, constant: -insets.right),
            titlePlaceholderLabel.topAnchor.constraint(equalTo: titleTextField.topAnchor, constant: insets.top),
            titlePlaceholderLabel.heightAnchor.constraint(equalToConstant: titleTextField.font!.lineHeight)
            ])

        NSLayoutConstraint.activate([
            separatorView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: defaultMargin),
            separatorView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -defaultMargin),
            separatorView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: separatorView.frame.height)
            ])

        NSLayoutConstraint.activate([
            richTextView.leftAnchor.constraint(equalTo: view.leftAnchor),
            richTextView.rightAnchor.constraint(equalTo: view.rightAnchor),
            richTextView.topAnchor.constraint(equalTo: view.topAnchor),
            richTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -defaultMargin)
            ])

        NSLayoutConstraint.activate([
            htmlTextView.leftAnchor.constraint(equalTo: richTextView.leftAnchor),
            htmlTextView.rightAnchor.constraint(equalTo: richTextView.rightAnchor),
            htmlTextView.topAnchor.constraint(equalTo: richTextView.topAnchor),
            htmlTextView.bottomAnchor.constraint(equalTo: richTextView.bottomAnchor)
            ])

        NSLayoutConstraint.activate([
            placeholderLabel.leftAnchor.constraint(equalTo: richTextView.leftAnchor, constant: Constants.placeholderPadding.left + defaultMargin),
            placeholderLabel.rightAnchor.constraint(equalTo: richTextView.rightAnchor, constant: Constants.placeholderPadding.right + defaultMargin),
            textPlaceholderTopConstraint,
            placeholderLabel.bottomAnchor.constraint(lessThanOrEqualTo: richTextView.bottomAnchor, constant: Constants.placeholderPadding.bottom)
            ])

        NSLayoutConstraint.activate([
            mediaProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mediaProgressView.widthAnchor.constraint(equalTo: view.widthAnchor),
            mediaProgressView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor)
            ])
    }

    private func configureDefaultProperties(for textView: UITextView, accessibilityLabel: String) {
        textView.accessibilityLabel = accessibilityLabel
        textView.font = Fonts.regular
        textView.keyboardDismissMode = .interactive
        textView.textColor = UIColor.darkText
        textView.translatesAutoresizingMaskIntoConstraints = false

        textView.textContainerInset.left = Constants.defaultMargin
        textView.textContainerInset.right = Constants.defaultMargin
    }

    func configureNavigationBar() {
        navigationController?.navigationBar.isTranslucent = false

        navigationItem.leftBarButtonItems = [separatorButtonItem, closeBarButtonItem, blogPickerBarButtonItem]
        navigationItem.rightBarButtonItems = [moreBarButtonItem, publishButton]
    }

    func configureDismissButton() {
        let image = isModal() ? Assets.closeButtonModalImage : Assets.closeButtonRegularImage
        closeButton.setImage(image, for: .normal)
    }

    func configureView() {
        edgesForExtendedLayout = UIRectEdge()
        view.backgroundColor = .white
    }

    func configureSubviews() {
        view.addSubview(richTextView)
        view.addSubview(htmlTextView)
        view.addSubview(titleTextField)
        view.addSubview(titlePlaceholderLabel)
        view.addSubview(separatorView)
        view.addSubview(placeholderLabel)
        mediaProgressView.isHidden = true
        view.addSubview(mediaProgressView)
    }

    func registerAttachmentImageProviders() {
        let providers: [TextViewAttachmentImageProvider] = [
            MoreAttachmentRenderer(),
            CommentAttachmentRenderer(font: Fonts.regular),
            HTMLAttachmentRenderer(font: Fonts.regular)
        ]

        for provider in providers {
            richTextView.registerAttachmentImageProvider(provider)
        }
    }

    func registerHTMLProcessors() {
        htmlPreProcessors.append(VideoProcessor.videoPressPreProcessor)
        htmlPreProcessors.append(VideoProcessor.wordPressVideoPreProcessor)

        htmlPostProcessors.append(VideoProcessor.videoPressPostProcessor)
        htmlPostProcessors.append(VideoProcessor.wordPressVideoPostProcessor)
    }

    func startListeningToNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
    }

    func stopListeningToNotifications() {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        nc.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
    }

    func rememberFirstResponder() {
        lastFirstResponder = view.findFirstResponder()
    }

    func restoreFirstResponder() {
        let nextFirstResponder = lastFirstResponder ?? titleTextField
        nextFirstResponder.becomeFirstResponder()
    }

    func refreshInterface() {
        reloadBlogPickerButton()
        reloadEditorContents()
        resizeBlogPickerButton()
        reloadPublishButton()
    }

    func setHTML(_ html: String) {
        var processedHTML = html
        for processor in htmlPreProcessors {
            processedHTML = processor.process(text: processedHTML)
        }
        richTextView.setHTML(processedHTML)
        self.processVideoPressAttachments()
    }

    func getHTML() -> String {
        var processedHTML = richTextView.getHTML()
        for processor in htmlPostProcessors {
            processedHTML = processor.process(text: processedHTML)
        }
        return processedHTML
    }

    func reloadEditorContents() {
        let content = post.content ?? String()

        titleTextField.text = post.postTitle
        setHTML(content)
    }

    func reloadBlogPickerButton() {
        var pickerTitle = post.blog.url ?? String()
        if let blogName = post.blog.settings?.name, blogName.isEmpty == false {
            pickerTitle = blogName
        }

        let titleText = NSAttributedString(string: pickerTitle, attributes: [NSFontAttributeName: Fonts.blogPicker])
        let shouldEnable = !isSingleSiteMode

        blogPickerButton.setAttributedTitle(titleText, for: .normal)
        blogPickerButton.buttonMode = shouldEnable ? .multipleSite : .singleSite
        blogPickerButton.isEnabled = shouldEnable
    }

    func reloadPublishButton() {
        publishButton.title = postEditorStateContext.publishButtonText
        publishButton.isEnabled = postEditorStateContext.isPublishButtonEnabled
    }

    func resizeBlogPickerButton() {
        // Ensure the BlogPicker gets it's maximum possible size
        blogPickerButton.sizeToFit()

        // Cap the size, according to the current traits
        var blogPickerSize = hasHorizontallyCompactView() ? Constants.blogPickerCompactSize : Constants.blogPickerRegularSize
        blogPickerSize.width = min(blogPickerSize.width, blogPickerButton.frame.width)

        blogPickerButton.frame.size = blogPickerSize
    }


    // MARK: - Keyboard Handling

    func keyboardWillShow(_ notification: Foundation.Notification) {
        guard
            let userInfo = notification.userInfo as? [String: AnyObject],
            let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else {
                return
        }

        refreshInsets(forKeyboardFrame: keyboardFrame)
    }

    func keyboardWillHide(_ notification: Foundation.Notification) {
        guard
            let userInfo = notification.userInfo as? [String: AnyObject],
            let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else {
                return
        }

        refreshInsets(forKeyboardFrame: keyboardFrame)
        dismissOptionsViewControllerIfNecessary()
    }

    fileprivate func refreshInsets(forKeyboardFrame keyboardFrame: CGRect) {
        let referenceView: UIScrollView = mode == .richText ? richTextView : htmlTextView

        let scrollInsets = UIEdgeInsets(top: referenceView.scrollIndicatorInsets.top, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)
        let contentInsets  = UIEdgeInsets(top: referenceView.contentInset.top, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)

        htmlTextView.scrollIndicatorInsets = scrollInsets
        htmlTextView.contentInset = contentInsets

        richTextView.scrollIndicatorInsets = scrollInsets
        richTextView.contentInset = contentInsets
    }

    func updateFormatBar() {
        guard let toolbar = richTextView.inputAccessoryView as? Aztec.FormatBar else {
            return
        }

        var identifiers = [FormattingIdentifier]()
        if richTextView.selectedRange.length > 0 {
            identifiers = richTextView.formatIdentifiersSpanningRange(richTextView.selectedRange)
        } else {
            identifiers = richTextView.formatIdentifiersForTypingAttributes()
        }

        toolbar.selectItemsMatchingIdentifiers(identifiers)
    }
}


// MARK: - SDK Workarounds!
//
extension AztecPostViewController {

    /// Note:
    /// When presenting an UIAlertController using a navigationBarButton as a source, the entire navigationBar
    /// gets set as a passthru view, allowing invalid scenarios, such as: pressing the Dismiss Button, while there's
    /// an ActionSheet onscreen.
    ///
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        super.present(viewControllerToPresent, animated: flag) {
            if let alert = viewControllerToPresent as? UIAlertController, alert.preferredStyle == .actionSheet {
                alert.popoverPresentationController?.passthroughViews = nil
            }

            completion?()
        }
    }
}


// MARK: - Actions
//
extension AztecPostViewController {
    @IBAction func publishButtonTapped(sender: UIBarButtonItem) {
        trackPostSave(stat: postEditorStateContext.publishActionAnalyticsStat)

        publishTapped(dismissWhenDone: true)
    }

    @IBAction func secondaryPublishButtonTapped(dismissWhenDone: Bool = true) {
        let publishPostClosure = {
            if self.postEditorStateContext.secondaryPublishButtonAction == .save {
                self.post.status = .draft
            } else if self.postEditorStateContext.secondaryPublishButtonAction == .publish {
                self.post.date_created_gmt = Date()
                self.post.status = .publish
            }

            if let stat = self.postEditorStateContext.secondaryPublishActionAnalyticsStat {
                self.trackPostSave(stat: stat)
            }

            self.publishTapped(dismissWhenDone: dismissWhenDone)
        }

        if presentedViewController != nil {
            dismiss(animated: true, completion: publishPostClosure)
        } else {
            publishPostClosure()
        }
    }

    func showPostHasChangesAlert() {
        let alertController = UIAlertController(
            title: NSLocalizedString("You have unsaved changes.", comment: "Title of message with options that shown when there are unsaved changes and the author is trying to move away from the post."),
            message: nil,
            preferredStyle: .actionSheet)

        // Button: Keep editing
        alertController.addCancelActionWithTitle(NSLocalizedString("Keep Editing", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post."))

        // Button: Save Draft/Update Draft
        if post.hasLocalChanges() {
            if !post.hasRemote() {
                // The post is a local draft or an autosaved draft: Discard or Save
                alertController.addDefaultActionWithTitle(NSLocalizedString("Save Draft", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post.")) { _ in
                    self.post.status = .draft
                    self.trackPostSave(stat: self.postEditorStateContext.publishActionAnalyticsStat)
                    self.publishTapped(dismissWhenDone: true)
                }
            } else if post.status == .draft {
                // The post was already a draft
                alertController.addDefaultActionWithTitle(NSLocalizedString("Update Draft", comment: "Button shown if there are unsaved changes and the author is trying to move away from an already published/saved post.")) { _ in
                    self.trackPostSave(stat: self.postEditorStateContext.publishActionAnalyticsStat)
                    self.publishTapped(dismissWhenDone: true)
                }
            }
        }

        // Button: Discard
        alertController.addDestructiveActionWithTitle(NSLocalizedString("Discard", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post.")) { _ in
            self.discardChangesAndUpdateGUI()
        }

        alertController.popoverPresentationController?.barButtonItem = closeBarButtonItem
        present(alertController, animated: true, completion: nil)
    }

    private func publishTapped(dismissWhenDone: Bool) {
        // Cancel publishing if media is currently being uploaded
        if mediaProgressCoordinator.isRunning {
            displayMediaIsUploadingAlert()
            return
        }

        // If there is any failed media allow it to be removed or cancel publishing
        if mediaProgressCoordinator.hasFailedMedia {
            let alertController = UIAlertController(title: FailedMediaRemovalAlert.title, message: FailedMediaRemovalAlert.message, preferredStyle: .alert)
            alertController.addDefaultActionWithTitle(MediaUploadingAlert.acceptTitle) { alertAction in
                self.removeFailedMedia()
                // Failed media is removed, try again.
                // Note: Intentionally not tracking another analytics stat here (no appropriate one exists yet)
                self.publishTapped(dismissWhenDone: dismissWhenDone)
            }

            alertController.addCancelActionWithTitle(FailedMediaRemovalAlert.cancelTitle)
            present(alertController, animated: true, completion: nil)
            return
        }
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.show(withStatus: postEditorStateContext.publishVerbText)
        postEditorStateContext.updated(isBeingPublished: true)

        // Finally, publish the post.
        publishPost() { uploadedPost, error in
            self.postEditorStateContext.updated(isBeingPublished: false)
            SVProgressHUD.dismiss()

            let generator = UINotificationFeedbackGenerator()
            generator.prepare()

            if let error = error {
                DDLogError("Error publishing post: \(error.localizedDescription)")

                SVProgressHUD.showDismissibleError(withStatus: self.postEditorStateContext.publishErrorText)
                generator.notificationOccurred(.error)
            } else if let uploadedPost = uploadedPost {
                self.post = uploadedPost

                generator.notificationOccurred(.success)
            }

            if dismissWhenDone {
                self.dismissOrPopView(didSave: true)
            } else {
                self.createRevisionOfPost()
            }
        }
    }

    @IBAction func closeWasPressed() {
        cancelEditing()
    }

    @IBAction func blogPickerWasPressed() {
        assert(isSingleSiteMode == false)
        guard post.hasSiteSpecificChanges() else {
            displayBlogSelector()
            return
        }

        displaySwitchSiteAlert()
    }

    @IBAction func moreWasPressed() {
        displayMoreSheet()
    }

    private func trackPostSave(stat: WPAnalyticsStat) {
        guard stat != .editorSavedDraft && stat != .editorQuickSavedDraft else {
            WPAppAnalytics.track(stat, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with:post.blog)
            return
        }

        let originalWordCount = post.original?.content?.wordCount() ?? 0
        let wordCount = post.content?.wordCount() ?? 0
        var properties: [String: Any] = ["word_count": wordCount, WPAppAnalyticsKeyEditorSource: Analytics.editorSource]
        if post.hasRemote() {
            properties["word_diff_count"] = originalWordCount
        }

        if stat == .editorPublishedPost {
            properties[WPAnalyticsStatEditorPublishedPostPropertyCategory] = post.hasCategories()
            properties[WPAnalyticsStatEditorPublishedPostPropertyPhoto] = post.hasPhoto()
            properties[WPAnalyticsStatEditorPublishedPostPropertyTag] = post.hasTags()
            properties[WPAnalyticsStatEditorPublishedPostPropertyVideo] = post.hasVideo()
        }

        WPAppAnalytics.track(stat, withProperties: properties, with: post)
    }
}


// MARK: - Private Helpers
//
private extension AztecPostViewController {

    func displayBlogSelector() {
        guard let sourceView = blogPickerButton.imageView else {
            fatalError()
        }

        // Setup Handlers
        let successHandler: BlogSelectorSuccessHandler = { selectedObjectID in
            self.dismiss(animated: true, completion: nil)

            guard let blog = self.mainContext.object(with: selectedObjectID) as? Blog else {
                return
            }
            self.recreatePostRevision(in: blog)
            self.mediaLibraryDataSource = WPAndDeviceMediaLibraryDataSource(post: self.post)
        }

        let dismissHandler: BlogSelectorDismissHandler = {
            self.dismiss(animated: true, completion: nil)
        }

        // Setup Picker
        let selectorViewController = BlogSelectorViewController(selectedBlogObjectID: post.blog.objectID,
                                                                successHandler: successHandler,
                                                                dismissHandler: dismissHandler)
        selectorViewController.title = NSLocalizedString("Select Site", comment: "Blog Picker's Title")
        selectorViewController.displaysPrimaryBlogOnTop = true

        // Note:
        // On iPad Devices, we'll disable the Picker's SearchController's "Autohide Navbar Feature", since
        // upon dismissal, it may force the NavigationBar to show up, even when it was initially hidden.
        selectorViewController.displaysNavigationBarWhenSearching = WPDeviceIdentification.isiPad()

        // Setup Navigation
        let navigationController = AdaptiveNavigationController(rootViewController: selectorViewController)
        navigationController.configurePopoverPresentationStyle(from: sourceView)

        // Done!
        present(navigationController, animated: true, completion: nil)
    }

    func displayMoreSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if postEditorStateContext.isSecondaryPublishButtonShown,
            let buttonTitle = postEditorStateContext.secondaryPublishButtonText {
            let dismissWhenDone = postEditorStateContext.secondaryPublishButtonAction == .publish
            alert.addActionWithTitle(buttonTitle, style: dismissWhenDone ? .destructive : .default ) { _ in
                self.secondaryPublishButtonTapped(dismissWhenDone: dismissWhenDone)
            }
        }

        alert.addDefaultActionWithTitle(MoreSheetAlert.previewTitle) { _ in
            self.displayPreview()
        }

        alert.addDefaultActionWithTitle(MoreSheetAlert.optionsTitle) { _ in
            self.displayPostOptions()
        }

        alert.addCancelActionWithTitle(MoreSheetAlert.cancelTitle)
        alert.popoverPresentationController?.barButtonItem = moreBarButtonItem

        present(alert, animated: true, completion: nil)
    }

    func displaySwitchSiteAlert() {
        let alert = UIAlertController(title: SwitchSiteAlert.title, message: SwitchSiteAlert.message, preferredStyle: .alert)

        alert.addDefaultActionWithTitle(SwitchSiteAlert.acceptTitle) { _ in
            self.displayBlogSelector()
        }

        alert.addCancelActionWithTitle(SwitchSiteAlert.cancelTitle)

        present(alert, animated: true, completion: nil)
    }

    func displayPostOptions() {
        let settingsViewController: PostSettingsViewController
        if post is Page {
            settingsViewController = PageSettingsViewController(post: post)
        } else {
            settingsViewController = PostSettingsViewController(post: post)
        }
        settingsViewController.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(settingsViewController, animated: true)
    }

    func displayPreview() {
        let previewController = PostPreviewViewController(post: post)
        previewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(previewController, animated: true)
    }

    func displayMediaIsUploadingAlert() {
        let alertController = UIAlertController(title: MediaUploadingAlert.title, message: MediaUploadingAlert.message, preferredStyle: .alert)
        alertController.addDefaultActionWithTitle(MediaUploadingAlert.acceptTitle)
        present(alertController, animated: true, completion: nil)
    }
}


// MARK: - PostEditorStateContextDelegate & support methods
//
extension AztecPostViewController: PostEditorStateContextDelegate {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            return
        }

        switch keyPath {
        case BasePost.statusKeyPath:
            if let status = post.status {
                postEditorStateContext.updated(postStatus: status)
                editorContentWasUpdated()
            }
        case #keyPath(AbstractPost.dateCreated):
            let dateCreated = post.dateCreated ?? Date()
            postEditorStateContext.updated(publishDate: dateCreated)
            editorContentWasUpdated()
        case #keyPath(AbstractPost.content):
            editorContentWasUpdated()
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private var editorHasContent: Bool {
        let titleIsEmpty = post.postTitle?.isEmpty ?? true
        let contentIsEmpty = post.content?.isEmpty ?? true

        return !titleIsEmpty || !contentIsEmpty
    }

    private var editorHasChanges: Bool {
        return post.hasUnsavedChanges()
    }

    internal func editorContentWasUpdated() {
        postEditorStateContext.updated(hasContent: editorHasContent)
        postEditorStateContext.updated(hasChanges: editorHasChanges)
    }

    internal func context(_ context: PostEditorStateContext, didChangeAction: PostEditorAction) {
        reloadPublishButton()
    }

    internal func context(_ context: PostEditorStateContext, didChangeActionAllowed: Bool) {
        reloadPublishButton()
    }

    internal func addObservers(toPost: AbstractPost) {
        toPost.addObserver(self, forKeyPath: AbstractPost.statusKeyPath, options: [], context: nil)
        toPost.addObserver(self, forKeyPath: #keyPath(AbstractPost.dateCreated), options: [], context: nil)
        toPost.addObserver(self, forKeyPath: #keyPath(AbstractPost.content), options: [], context: nil)
    }

    internal func removeObservers(fromPost: AbstractPost) {
        fromPost.removeObserver(self, forKeyPath: AbstractPost.statusKeyPath)
        fromPost.removeObserver(self, forKeyPath: #keyPath(AbstractPost.dateCreated))
        fromPost.removeObserver(self, forKeyPath: #keyPath(AbstractPost.content))
    }
}


// MARK: - UITextViewDelegate methods
//
extension AztecPostViewController : UITextViewDelegate {
    func textViewDidChangeSelection(_ textView: UITextView) {
        updateFormatBar()
        changeRichTextInputView(to: nil)
    }

    func textViewDidChange(_ textView: UITextView) {
        mapUIContentToPostAndSave()
        refreshPlaceholderVisibility()

        switch textView {
        case titleTextField:
            updateTitleHeight()
        case richTextView:
            updateFormatBar()
        default:
            break
        }
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        switch textView {
        case titleTextField:
            formatBar.enabled = false
        case richTextView:
            formatBar.enabled = true
        case htmlTextView:
            formatBar.enabled = false

            // Disable the bar, except for the source code button
            let htmlButton = formatBar.overflowItems.first(where: { $0.identifier == FormattingIdentifier.sourcecode })
            htmlButton?.isEnabled = true
        default:
            break
        }

        textView.inputAccessoryView = formatBar

        return true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTitlePosition()
    }
}


// MARK: - UITextFieldDelegate methods
//
extension AztecPostViewController {
    func titleTextFieldDidChange(_ textField: UITextField) {
        mapUIContentToPostAndSave()
        editorContentWasUpdated()
    }
}


// MARK: - TextViewFormattingDelegate methods
//
extension AztecPostViewController: Aztec.TextViewFormattingDelegate {
    func textViewCommandToggledAStyle() {
        updateFormatBar()
    }
}


// MARK: - HTML Mode Switch methods
//
extension AztecPostViewController {
    enum EditionMode {
        case richText
        case html

        mutating func toggle() {
            switch self {
            case .richText:
                self = .html
            case .html:
                self = .richText
            }
        }
    }

    fileprivate func switchToHTML() {
        stopEditing()

        htmlTextView.text = getHTML()
        htmlTextView.becomeFirstResponder()

        refreshEditorVisibility()
        refreshPlaceholderVisibility()
    }

    fileprivate func switchToRichText() {
        stopEditing()

        setHTML(htmlTextView.text)
        richTextView.becomeFirstResponder()

        refreshEditorVisibility()
        refreshPlaceholderVisibility()
    }

    func refreshEditorVisibility() {
        let isRichEnabled = mode == .richText

        htmlTextView.isHidden = isRichEnabled
        richTextView.isHidden = !isRichEnabled
    }

    func refreshPlaceholderVisibility() {
        placeholderLabel.isHidden = richTextView.isHidden || !richTextView.text.isEmpty
        titlePlaceholderLabel.isHidden = !titleTextField.text.isEmpty
    }
}


// MARK: - FormatBarDelegate Conformance
//
extension AztecPostViewController : Aztec.FormatBarDelegate {

    func formatBarTouchesBegan(_ formatBar: FormatBar) {
        dismissOptionsViewControllerIfNecessary()
    }

    func handleActionForIdentifier(_ identifier: FormattingIdentifier, barItem: FormatBarItem) {

        switch identifier {
        case .bold:
            toggleBold()
        case .italic:
            toggleItalic()
        case .underline:
            toggleUnderline()
        case .strikethrough:
            toggleStrikethrough()
        case .blockquote:
            toggleBlockquote()
        case .unorderedlist, .orderedlist:
            toggleList(fromItem: barItem)
        case .link:
            toggleLink()
        case .media:
            presentMediaPicker()
        case .sourcecode:
            toggleEditingMode()
        case .p, .header1, .header2, .header3, .header4, .header5, .header6:
            toggleHeader(fromItem: barItem)
        case .horizontalruler:
            insertHorizontalRuler()
        case .more:
            insertMore()
        }

        updateFormatBar()
    }

    func formatBar(_ formatBar: FormatBar, didChangeOverflowState overflowState: FormatBarOverflowState) {
        let action = overflowState == .visible ? "made_visible" : "made_hidden"
        WPAppAnalytics.track(.editorTappedMoreItems, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource, "action": action], with: post)
    }


    func toggleBold() {
        WPAppAnalytics.track(.editorTappedBold, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.toggleBold(range: richTextView.selectedRange)
    }


    func toggleItalic() {
        WPAppAnalytics.track(.editorTappedItalic, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.toggleItalic(range: richTextView.selectedRange)
    }


    func toggleUnderline() {
        WPAppAnalytics.track(.editorTappedUnderline, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.toggleUnderline(range: richTextView.selectedRange)
    }


    func toggleStrikethrough() {
        WPAppAnalytics.track(.editorTappedStrikethrough, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.toggleStrikethrough(range: richTextView.selectedRange)
    }


    func toggleList(fromItem item: FormatBarItem) {
        let listOptions = Constants.lists.map { (listType) -> OptionsTableViewOption in
            return OptionsTableViewOption(image: listType.iconImage, title: NSAttributedString(string: listType.description, attributes: [:]))
        }

        var index: Int? = nil
        if let listType = listTypeForSelectedText() {
            index = Constants.lists.index(of: listType)
        }

        showOptionsTableViewControllerWithOptions(listOptions,
                                                  fromBarItem: item,
                                                  selectedRowIndex: index,
                                                  onSelect: { [weak self] selected in
                                                    guard let range = self?.richTextView.selectedRange else { return }

                                                    let listType = Constants.lists[selected]
                                                    switch listType {
                                                    case .unordered:
                                                        WPAppAnalytics.track(.editorTappedUnorderedList, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: self?.post)
                                                        self?.richTextView.toggleUnorderedList(range: range)
                                                    case .ordered:
                                                        WPAppAnalytics.track(.editorTappedOrderedList, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: self?.post)
                                                        self?.richTextView.toggleOrderedList(range: range)
                                                    }

                                                    self?.optionsViewController = nil
        })
    }


    func toggleBlockquote() {
        WPAppAnalytics.track(.editorTappedBlockquote, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.toggleBlockquote(range: richTextView.selectedRange)
    }


    func listTypeForSelectedText() -> TextList.Style? {
        var identifiers = [FormattingIdentifier]()
        if (richTextView.selectedRange.length > 0) {
            identifiers = richTextView.formatIdentifiersSpanningRange(richTextView.selectedRange)
        } else {
            identifiers = richTextView.formatIdentifiersForTypingAttributes()
        }
        let mapping: [FormattingIdentifier: TextList.Style] = [
            .orderedlist: .ordered,
            .unorderedlist: .unordered
        ]
        for (key,value) in mapping {
            if identifiers.contains(key) {
                return value
            }
        }

        return nil
    }


    func toggleLink() {
        WPAppAnalytics.track(.editorTappedLink, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)

        var linkTitle = ""
        var linkURL: URL? = nil
        var linkRange = richTextView.selectedRange
        // Let's check if the current range already has a link assigned to it.
        if let expandedRange = richTextView.linkFullRange(forRange: richTextView.selectedRange) {
            linkRange = expandedRange
            linkURL = richTextView.linkURL(forRange: expandedRange)
        }

        linkTitle = richTextView.attributedText.attributedSubstring(from: linkRange).string
        showLinkDialog(forURL: linkURL, title: linkTitle, range: linkRange)
    }


    func showLinkDialog(forURL url: URL?, title: String?, range: NSRange) {

        let isInsertingNewLink = (url == nil)
        var urlToUse = url

        if isInsertingNewLink {
            let pasteboard = UIPasteboard.general
            if let pastedURL = pasteboard.value(forPasteboardType:String(kUTTypeURL)) as? URL {
                urlToUse = pastedURL
            }
        }


        let insertButtonTitle = isInsertingNewLink ? NSLocalizedString("Insert Link", comment: "Label action for inserting a link on the editor") : NSLocalizedString("Update Link", comment: "Label action for updating a link on the editor")
        let removeButtonTitle = NSLocalizedString("Remove Link", comment: "Label action for removing a link from the editor")
        let cancelButtonTitle = NSLocalizedString("Cancel", comment: "Cancel button")

        let alertController = UIAlertController(title: insertButtonTitle,
                                                message: nil,
                                                preferredStyle: UIAlertControllerStyle.alert)

        alertController.addTextField(configurationHandler: { [weak self]textField in
            textField.clearButtonMode = UITextFieldViewMode.always
            textField.placeholder = NSLocalizedString("URL", comment: "URL text field placeholder")

            textField.text = urlToUse?.absoluteString

            textField.addTarget(self,
                action: #selector(AztecPostViewController.alertTextFieldDidChange),
                for: UIControlEvents.editingChanged)
            })

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextFieldViewMode.always
            textField.placeholder = NSLocalizedString("Link Name", comment: "Link name field placeholder")
            textField.isSecureTextEntry = false
            textField.autocapitalizationType = UITextAutocapitalizationType.sentences
            textField.autocorrectionType = UITextAutocorrectionType.default
            textField.spellCheckingType = UITextSpellCheckingType.default

            textField.text = title
        })

        let insertAction = UIAlertAction(title: insertButtonTitle,
                                         style: UIAlertActionStyle.default,
                                         handler: { [weak self] action in

                                            self?.richTextView.becomeFirstResponder()
                                            let linkURLString = alertController.textFields?.first?.text
                                            var linkTitle = alertController.textFields?.last?.text

                                            if  linkTitle == nil  || linkTitle!.isEmpty {
                                                linkTitle = linkURLString
                                            }

                                            guard
                                                let urlString = linkURLString,
                                                let url = URL(string: urlString),
                                                let title = linkTitle
                                                else {
                                                    return
                                            }
                                            self?.richTextView.setLink(url, title: title, inRange: range)
            })

        let removeAction = UIAlertAction(title: removeButtonTitle,
                                         style: UIAlertActionStyle.destructive,
                                         handler: { [weak self] action in
                                            WPAppAnalytics.track(.editorTappedUnlink, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: self?.post)
                                            self?.richTextView.becomeFirstResponder()
                                            self?.richTextView.removeLink(inRange: range)
            })

        let cancelAction = UIAlertAction(title: cancelButtonTitle,
                                         style: UIAlertActionStyle.cancel,
                                         handler: { [weak self]action in
                                            self?.richTextView.becomeFirstResponder()
            })

        alertController.addAction(insertAction)
        if !isInsertingNewLink {
            alertController.addAction(removeAction)
        }
        alertController.addAction(cancelAction)

        // Disabled until url is entered into field
        if let text = alertController.textFields?.first?.text {
            insertAction.isEnabled = !text.isEmpty
        }

        self.present(alertController, animated: true, completion: nil)
    }

    func alertTextFieldDidChange(_ textField: UITextField) {
        guard
            let alertController = presentedViewController as? UIAlertController,
            let urlFieldText = alertController.textFields?.first?.text,
            let insertAction = alertController.actions.first
            else {
                return
        }

        insertAction.isEnabled = !urlFieldText.isEmpty
    }

    func presentMediaPicker(animated: Bool = true) {
        WPAppAnalytics.track(.editorTappedImage, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)

        let picker = WPNavigationMediaPickerViewController()
        picker.dataSource = mediaLibraryDataSource
        picker.showMostRecentFirst = true
        picker.filter = WPMediaType.videoOrImage
        picker.delegate = self
        picker.modalPresentationStyle = .currentContext

        present(picker, animated: animated, completion: nil)
    }

    func toggleEditingMode() {
        if mediaProgressCoordinator.isRunning {
            displayMediaIsUploadingAlert()
            return
        }

        WPAppAnalytics.track(.editorTappedHTML, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        mode.toggle()
    }

    fileprivate func dismissOptionsViewControllerIfNecessary() {
        if let optionsViewController = optionsViewController,
            presentedViewController == optionsViewController {
            dismiss(animated: true, completion: nil)
            self.optionsViewController = nil
        }
    }

    func toggleHeader(fromItem item: FormatBarItem) {
        WPAppAnalytics.track(.editorTappedHeader, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: self.post)

        let headerOptions = Constants.headers.map { (headerType) -> OptionsTableViewOption in
            return OptionsTableViewOption(image: headerType.iconImage,
                                          title: NSAttributedString(string: headerType.description,
                                                                    attributes:[NSFontAttributeName: UIFont.systemFont(ofSize: headerType.fontSize)]))
        }

        let selectedIndex = Constants.headers.index(of: self.headerLevelForSelectedText())

        showOptionsTableViewControllerWithOptions(headerOptions,
                                                  fromBarItem: item,
                                                  selectedRowIndex: selectedIndex,
                                                  onSelect: { [weak self] selected in
                                                    guard let range = self?.richTextView.selectedRange else { return }

                                                    let selectedStyle = Analytics.headerStyleValues[selected]
                                                    WPAppAnalytics.track(.editorTappedHeaderSelection, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource, "heading_style": selectedStyle], with: self?.post)

                                                    self?.richTextView.toggleHeader(Constants.headers[selected], range: range)
                                                    self?.optionsViewController = nil
                                                    self?.changeRichTextInputView(to: nil)
        })
    }

    func showOptionsTableViewControllerWithOptions(_ options: [OptionsTableViewOption],
                                                   fromBarItem barItem: FormatBarItem,
                                                   selectedRowIndex index: Int?,
                                                   onSelect: OptionsTableViewController.OnSelectHandler?) {
        // Hide the input view if we're already showing these options
        if let optionsViewController = optionsViewController ?? (presentedViewController as? OptionsTableViewController), optionsViewController.options == options {
            if self.optionsViewController != nil && presentedViewController != nil {
                dismiss(animated: true, completion: nil)
            }

            self.optionsViewController = nil
            changeRichTextInputView(to: nil)
            return
        }

        optionsViewController = OptionsTableViewController(options: options)
        optionsViewController.cellDeselectedTintColor = WPStyleGuide.aztecFormatBarInactiveColor
        optionsViewController.view.tintColor = WPStyleGuide.aztecFormatBarActiveColor
        optionsViewController.onSelect = { [weak self] selected in
            if self?.presentedViewController != nil {
                self?.dismiss(animated: true, completion: nil)
            }

            onSelect?(selected)
        }

        let selectRow = {
            guard let index = index else {
                return
            }

            self.optionsViewController?.selectRow(at: index)
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            presentOptionsViewController(optionsViewController, asPopoverFromBarItem: barItem, completion: selectRow)
        } else {
            presentOptionsViewControllerAsInputView(optionsViewController)
            selectRow()
        }
    }

    private func presentOptionsViewController(_ optionsViewController: OptionsTableViewController,
                                              asPopoverFromBarItem barItem: FormatBarItem,
                                              completion: (() -> Void)? = nil) {
        optionsViewController.modalPresentationStyle = .popover
        optionsViewController.popoverPresentationController?.permittedArrowDirections = [.down]
        optionsViewController.popoverPresentationController?.sourceView = view

        let frame = barItem.superview?.convert(barItem.frame, to: UIScreen.main.coordinateSpace)

        optionsViewController.popoverPresentationController?.sourceRect = view.convert(frame!, from: UIScreen.main.coordinateSpace)
        optionsViewController.popoverPresentationController?.backgroundColor = .white
        optionsViewController.popoverPresentationController?.delegate = self

        present(optionsViewController, animated: true, completion: completion)
    }

    private func presentOptionsViewControllerAsInputView(_ optionsViewController: OptionsTableViewController) {
        self.addChildViewController(optionsViewController)
        changeRichTextInputView(to: optionsViewController.view)
        optionsViewController.didMove(toParentViewController: self)
    }

    func insertHorizontalRuler() {
        WPAppAnalytics.track(.editorTappedHorizontalRule, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.replaceRangeWithHorizontalRuler(richTextView.selectedRange)
    }

    func insertMore() {
        WPAppAnalytics.track(.editorTappedMore, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
        richTextView.replaceRangeWithCommentAttachment(richTextView.selectedRange, text: Constants.moreAttachmentText)
    }

    func changeRichTextInputView(to: UIView?) {
        guard richTextView.inputView != to else {
            return
        }

        richTextView.resignFirstResponder()
        richTextView.inputView = to
        richTextView.becomeFirstResponder()
    }

    func headerLevelForSelectedText() -> Header.HeaderType {
        var identifiers = [FormattingIdentifier]()
        if (richTextView.selectedRange.length > 0) {
            identifiers = richTextView.formatIdentifiersSpanningRange(richTextView.selectedRange)
        } else {
            identifiers = richTextView.formatIdentifiersForTypingAttributes()
        }
        let mapping: [FormattingIdentifier: Header.HeaderType] = [
            .header1: .h1,
            .header2: .h2,
            .header3: .h3,
            .header4: .h4,
            .header5: .h5,
            .header6: .h6,
        ]
        for (key,value) in mapping {
            if identifiers.contains(key) {
                return value
            }
        }
        return .none
    }


    // MARK: - Toolbar creation

    func makeToolbarButton(identifier: FormattingIdentifier) -> FormatBarItem {
        let button = FormatBarItem(image: identifier.iconImage, identifier: identifier)
        button.accessibilityLabel = identifier.accessibilityLabel
        button.accessibilityIdentifier = identifier.accessibilityIdentifier
        return button
    }

    func createToolbar() -> Aztec.FormatBar {
        let mediaItem = makeToolbarButton(identifier: .media)
        let scrollableItems = scrollableItemsForToolbar
        let overflowItems = overflowItemsForToolbar

        let toolbar = Aztec.FormatBar()
        toolbar.defaultItems = [[mediaItem], scrollableItems]
        toolbar.overflowItems = overflowItems
        toolbar.tintColor = WPStyleGuide.aztecFormatBarInactiveColor
        toolbar.highlightedTintColor = WPStyleGuide.aztecFormatBarActiveColor
        toolbar.selectedTintColor = WPStyleGuide.aztecFormatBarActiveColor
        toolbar.disabledTintColor = WPStyleGuide.aztecFormatBarDisabledColor
        toolbar.dividerTintColor = WPStyleGuide.aztecFormatBarDisabledColor
        toolbar.overflowToggleIcon = Gridicon.iconOfType(.ellipsis)
        toolbar.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44.0)
        toolbar.formatter = self

        return toolbar
    }

    var scrollableItemsForToolbar: [FormatBarItem] {
        let headerButton = makeToolbarButton(identifier: .p)

        var alternativeIcons = [FormattingIdentifier: UIImage]()
        let headings = Constants.headers.suffix(from: 1) // Remove paragraph style
        for heading in headings {
            alternativeIcons[heading.formattingIdentifier] = heading.iconImage
        }

        headerButton.alternativeIcons = alternativeIcons


        let listButton = makeToolbarButton(identifier: .unorderedlist)
        var listIcons = [FormattingIdentifier: UIImage]()
        for list in Constants.lists {
            listIcons[list.formattingIdentifier] = list.iconImage
        }

        listButton.alternativeIcons = listIcons

        return [
            headerButton,
            listButton,
            makeToolbarButton(identifier: .blockquote),
            makeToolbarButton(identifier: .bold),
            makeToolbarButton(identifier: .italic),
            makeToolbarButton(identifier: .link)
        ]
    }

    var overflowItemsForToolbar: [FormatBarItem] {
        return [
            makeToolbarButton(identifier: .underline),
            makeToolbarButton(identifier: .strikethrough),
            makeToolbarButton(identifier: .horizontalruler),
            makeToolbarButton(identifier: .more),
            makeToolbarButton(identifier: .sourcecode)
        ]
    }
}


// MARK: - UINavigationControllerDelegate Conformance
//
extension AztecPostViewController: UINavigationControllerDelegate {

}


// MARK: - UIPopoverPresentationControllerDelegate
//
extension AztecPostViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        if optionsViewController != nil {
            optionsViewController = nil
        }
    }
}


// MARK: - Unknown HTML
//
private extension AztecPostViewController {

    func displayUnknownHtmlEditor(for attachment: HTMLAttachment) {
        let targetVC = UnknownEditorViewController(attachment: attachment)
        targetVC.onDidSave = { [weak self] html in
            self?.richTextView.update(attachment: attachment, html: html)
            self?.dismiss(animated: true, completion: nil)
        }

        targetVC.onDidCancel = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }

        let navigationController = UINavigationController(rootViewController: targetVC)
        displayAsPopover(viewController: navigationController)
    }

    func displayAsPopover(viewController: UIViewController) {
        viewController.modalPresentationStyle = .popover
        viewController.preferredContentSize = view.frame.size

        let presentationController = viewController.popoverPresentationController
        presentationController?.sourceView = view
        presentationController?.delegate = self

        present(viewController, animated: true, completion: nil)
    }
}


// MARK: - Cancel/Dismiss/Persistence Logic
//
private extension AztecPostViewController {

    // TODO: Rip this out and put it into the PostService
    func createRevisionOfPost() {
        guard let context = post.managedObjectContext else {
            return
        }

        // Using performBlock: with the AbstractPost on the main context:
        // Prevents a hang on opening this view on slow and fast devices
        // by deferring the cloning and UI update.
        // Slower devices have the effect of the content appearing after
        // a short delay

        context.performAndWait {
            self.post = self.post.createRevision()
            ContextManager.sharedInstance().save(context)
        }
    }

    // TODO: Rip this and put it into PostService, as well
    func recreatePostRevision(in blog: Blog) {
        let shouldCreatePage = post is Page
        let postService = PostService(managedObjectContext: mainContext)
        let newPost = shouldCreatePage ? postService.createDraftPage(for: blog) : postService.createDraftPost(for: blog)

        newPost.content = contentByStrippingMediaAttachments()
        newPost.postTitle = post.postTitle
        newPost.password = post.password
        newPost.status = post.status
        newPost.dateCreated = post.dateCreated
        newPost.dateModified = post.dateModified

        if let source = post as? Post, let target = newPost as? Post {
            target.tags = source.tags
        }

        discardChanges()
        post = newPost
        createRevisionOfPost()
        RecentSitesService().touch(blog: blog)

        // TODO: Add this snippet, if needed, once we've relocated this helper to PostService
        //[self syncOptionsIfNecessaryForBlog:blog afterBlogChanged:YES];
    }

    func cancelEditing() {
        stopEditing()

        if post.canSave() && post.hasUnsavedChanges() {
            showPostHasChangesAlert()
        } else {
            discardChangesAndUpdateGUI()
        }
    }

    func stopEditing() {
        view.endEditing(true)
    }

    func discardChanges() {
        guard let context = post.managedObjectContext, let originalPost = post.original else {
            return
        }

        WPAppAnalytics.track(.editorDiscardedChanges, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)

        post = originalPost
        post.deleteRevision()

        if shouldRemovePostOnDismiss {
            post.remove()
        }

        mediaProgressCoordinator.cancelAllPendingUploads()
        ContextManager.sharedInstance().save(context)
    }

    func discardChangesAndUpdateGUI() {
        discardChanges()

        dismissOrPopView(didSave: false)
    }

    func dismissOrPopView(didSave: Bool) {
        stopEditing()

        WPAppAnalytics.track(.editorClosed, withProperties:[WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)

        if let onClose = onClose {
            onClose(didSave)
        } else if isModal() {
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }

    func contentByStrippingMediaAttachments() -> String {
        if mode == .html {
            setHTML(htmlTextView.text)
        }

        richTextView.removeTextAttachments()
        let strippedHTML = getHTML()

        if mode == .html {
            setHTML(strippedHTML)
        }

        return strippedHTML
    }

    func mapUIContentToPostAndSave() {
        post.postTitle = titleTextField.text
        // TODO: This may not be super performant; Instrument and improve if needed and remove this TODO
        if richTextView.isHidden {
            post.content = htmlTextView.text
        } else {
            post.content = getHTML()
        }

        ContextManager.sharedInstance().save(post.managedObjectContext!)
    }

    func publishPost(completion: ((_ post: AbstractPost?, _ error: Error?) -> Void)? = nil) {
        mapUIContentToPostAndSave()

        let managedObjectContext = ContextManager.sharedInstance().mainContext
        let postService = PostService(managedObjectContext: managedObjectContext)
        postService.uploadPost(post, success: { uploadedPost in
            completion?(uploadedPost, nil)
        }) { error in
            completion?(nil, error)
        }
    }
}


// MARK: - Computed Properties
//
private extension AztecPostViewController {
    var mainContext: NSManagedObjectContext {
        return ContextManager.sharedInstance().mainContext
    }

    var currentBlogCount: Int {
        let service = BlogService(managedObjectContext: mainContext)
        return service.blogCountForAllAccounts()
    }

    var isSingleSiteMode: Bool {
        return currentBlogCount <= 1 || post.hasRemote()
    }
}


// MARK: - MediaProgressCoordinatorDelegate
//
extension AztecPostViewController: MediaProgressCoordinatorDelegate {

    func configureMediaAppearance() {
        MediaAttachment.appearance.progressBackgroundColor = Colors.mediaProgressBarBackground
        MediaAttachment.appearance.progressColor = Colors.mediaProgressBarTrack
        MediaAttachment.appearance.overlayColor = Colors.mediaProgressOverlay
    }

    func mediaProgressCoordinator(_ mediaProgressCoordinator: MediaProgressCoordinator, progressDidChange progress: Float) {
        mediaProgressView.isHidden = !mediaProgressCoordinator.isRunning
        mediaProgressView.progress = progress
        for (attachmentID, progress) in self.mediaProgressCoordinator.mediaUploading {
            guard let attachment = richTextView.attachment(withId: attachmentID) else {
                continue
            }
            if progress.fractionCompleted >= 1 {
                attachment.progress = nil
            } else {
                attachment.progress = progress.fractionCompleted
            }
            richTextView.refreshLayout(for: attachment)
        }
    }

    func mediaProgressCoordinatorDidStartUploading(_ mediaProgressCoordinator: MediaProgressCoordinator) {
        postEditorStateContext.update(isUploadingMedia: true)
    }

    func mediaProgressCoordinatorDidFinishUpload(_ mediaProgressCoordinator: MediaProgressCoordinator) {
        postEditorStateContext.update(isUploadingMedia: false)
    }
}

// MARK: - Media Support
//
extension AztecPostViewController {

    fileprivate func insertDeviceMedia(phAsset: PHAsset) {
        switch phAsset.mediaType {
        case .image:
            insertDeviceImage(phAsset: phAsset)
        case .video:
            insertDeviceVideo(phAsset: phAsset)
        default:
            return
        }
    }

    fileprivate func insertDeviceImage(phAsset: PHAsset) {
        let attachment = richTextView.insertImage(sourceURL: URL(string:"placeholder://")! , atPosition: self.richTextView.selectedRange.location, placeHolderImage:
                Assets.defaultMissingImage)

        let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
        mediaService.createMedia(with: phAsset, forPost: post.objectID, thumbnailCallback: { (thumbnailURL) in
            DispatchQueue.main.async {
                self.richTextView.update(attachment: attachment, alignment: attachment.alignment, size: attachment.size, url: thumbnailURL)
            }
        }, completion: { [weak self](media, error) in
            guard let strongSelf = self else {
                return
            }
            guard let media = media, error == nil else {
                DispatchQueue.main.async {
                    strongSelf.handleError(error as NSError?, onAttachment: attachment)
                }
                return
            }

            WPAppAnalytics.track(.editorAddedPhotoViaLocalLibrary, withProperties: WPAppAnalytics.properties(for: media), with: strongSelf.post.blog)

            strongSelf.upload(media: media, mediaID: attachment.identifier)
        })
    }

    fileprivate func insertDeviceVideo(phAsset: PHAsset) {
        let attachment = richTextView.insertVideo(atLocation: richTextView.selectedRange.location, sourceURL: URL(string:"placeholder://")!, posterURL: URL(string:"placeholder://")!, placeHolderImage: Assets.defaultMissingImage)

        let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
        mediaService.createMedia(with: phAsset, forPost: post.objectID, thumbnailCallback: { (thumbnailURL) in
            DispatchQueue.main.async {
                attachment.posterURL = thumbnailURL
                self.richTextView.refreshLayout(for: attachment)
            }
        }, completion: { [weak self](media, error) in
            guard let strongSelf = self else {
                return
            }
            guard let media = media, error == nil else {
                DispatchQueue.main.async {
                    strongSelf.handleError(error as NSError?, onAttachment: attachment)
                }
                return
            }

            WPAppAnalytics.track(.editorAddedVideoViaLocalLibrary, withProperties: WPAppAnalytics.properties(for: media), with: strongSelf.post.blog)

            strongSelf.upload(media: media, mediaID: attachment.identifier)
        })
    }

    fileprivate func insertSiteMediaLibrary(media: Media) {
        if media.hasRemote {
            insertRemoteSiteMediaLibrary(media: media)
        } else {
            insertLocalSiteMediaLibrary(media: media)
        }
    }

    fileprivate func insertRemoteSiteMediaLibrary(media: Media) {
        let insertLocation = richTextView.selectedRange.location
        guard let remoteURLStr = media.remoteURL, let remoteURL = URL(string: remoteURLStr) else {
            return
        }
        if media.mediaType == .image {
            let _ = richTextView.insertImage(sourceURL: remoteURL, atPosition: insertLocation, placeHolderImage: Assets.defaultMissingImage)
            WPAppAnalytics.track(.editorAddedPhotoViaWPMediaLibrary, withProperties: WPAppAnalytics.properties(for: media), with: post)
        } else if media.mediaType == .video {
            var posterURL: URL?
            if let posterURLString = media.remoteThumbnailURL {
                posterURL = URL(string: posterURLString)
            }
            let attachment = richTextView.insertVideo(atLocation: insertLocation, sourceURL: remoteURL, posterURL: posterURL, placeHolderImage: Assets.defaultMissingImage)
            if let videoPressGUID = media.videopressGUID, !videoPressGUID.isEmpty {
                attachment.videoPressID = videoPressGUID
                richTextView.update(attachment: attachment)
            }
            WPAppAnalytics.track(.editorAddedVideoViaWPMediaLibrary, withProperties: WPAppAnalytics.properties(for: media), with: post)
        }
        self.mediaProgressCoordinator.finishOneItem()
    }

    fileprivate func insertLocalSiteMediaLibrary(media: Media) {
        let insertLocation = richTextView.selectedRange.location
        var tempMediaURL = URL(string:"placeholder://")!
        if let absoluteURL = media.absoluteLocalURL {
            tempMediaURL = absoluteURL
        }
        var attachment: MediaAttachment?
        if media.mediaType == .image {
            attachment = self.richTextView.insertImage(sourceURL:tempMediaURL, atPosition: insertLocation, placeHolderImage: Assets.defaultMissingImage)
            WPAppAnalytics.track(.editorAddedPhotoViaWPMediaLibrary, withProperties: WPAppAnalytics.properties(for: media), with: post)
        } else if media.mediaType == .video,
            let remoteURLStr = media.remoteURL,
            let remoteURL = URL(string: remoteURLStr) {
            attachment = richTextView.insertVideo(atLocation: insertLocation, sourceURL: remoteURL, posterURL: media.absoluteThumbnailLocalURL, placeHolderImage: Assets.defaultMissingImage)
            WPAppAnalytics.track(.editorAddedVideoViaWPMediaLibrary, withProperties: WPAppAnalytics.properties(for: media), with: post)
        }
        if let attachment = attachment {
            upload(media: media, mediaID: attachment.identifier)
        }
    }

    fileprivate func saveToMedia(attachment: MediaAttachment) {
        guard let image = attachment.image else {
            return
        }
        mediaProgressCoordinator.track(numberOfItems: 1)
        let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
        mediaService.createMedia(with: image, withMediaID:"CopyPasteImage" , forPost: post.objectID, thumbnailCallback: { (thumbnailURL) in
            DispatchQueue.main.async {
                if let imageAttachment = attachment as? ImageAttachment {
                    self.richTextView.update(attachment: imageAttachment, alignment: imageAttachment.alignment, size: imageAttachment.size, url: thumbnailURL)
                }
            }
        }, completion: { [weak self](media, error) in
            guard let strongSelf = self else {
                return
            }
            guard let media = media, error == nil else {
                DispatchQueue.main.async {
                    strongSelf.handleError(error as NSError?, onAttachment: attachment)
                }
                return
            }

            if media.mediaType == .image {
                WPAppAnalytics.track(.editorAddedPhotoViaLocalLibrary, withProperties: WPAppAnalytics.properties(for: media), with: strongSelf.post.blog)
            } else if media.mediaType == .video {
                WPAppAnalytics.track(.editorAddedVideoViaLocalLibrary, withProperties: WPAppAnalytics.properties(for: media), with: strongSelf.post.blog)
            }

            strongSelf.upload(media: media, mediaID: attachment.identifier)
        })
    }

    private func upload(media: Media, mediaID: String) {
        guard let attachment = richTextView.attachment(withId: mediaID) else {
            return
        }
        let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
        var uploadProgress: Progress?
        mediaService.uploadMedia(media, progress: &uploadProgress, success: {[weak self]() in
            guard let strongSelf = self, let remoteURLStr = media.remoteURL, let remoteURL = URL(string: remoteURLStr) else {
                return
            }
            DispatchQueue.main.async {
                if let imageAttachment = attachment as? ImageAttachment {
                    strongSelf.richTextView.update(attachment: imageAttachment, alignment: imageAttachment.alignment, size: imageAttachment.size, url: remoteURL)
                } else if let videoAttachment = attachment as? VideoAttachment, let videoURLString = media.remoteURL {
                    videoAttachment.srcURL = URL(string: videoURLString)
                    if let videoPosterURLString = media.remoteThumbnailURL {
                        videoAttachment.posterURL = URL(string: videoPosterURLString)
                    }
                    if let videoPressGUID = media.videopressGUID, !videoPressGUID.isEmpty {
                        videoAttachment.videoPressID = videoPressGUID
                    }
                    strongSelf.richTextView.update(attachment: videoAttachment)
                }
            }
            }, failure: { [weak self](error) in
                guard let strongSelf = self else {
                    return
                }

                WPAppAnalytics.track(.editorUploadMediaFailed, withProperties: [WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: strongSelf.post.blog)

                DispatchQueue.main.async {
                    strongSelf.handleError(error as NSError, onAttachment: attachment)
                }
        })
        if let progress = uploadProgress {
            mediaProgressCoordinator.track(progress: progress, ofObject: media, withMediaID: mediaID)
        }
    }

    private func handleError(_ error: NSError?, onAttachment attachment: Aztec.MediaAttachment) {
        let message = NSLocalizedString("Failed to insert media.\n Please tap for options.", comment: "Error message to show to use when media insertion on a post fails")

        if let error = error {
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                return
            }
            mediaProgressCoordinator.attach(error: error, toMediaID: attachment.identifier)
        }

        let attributeMessage = NSAttributedString(string: message, attributes: mediaMessageAttributes)
        attachment.message = attributeMessage
        attachment.overlayImage = Gridicon.iconOfType(.refresh)
        richTextView.refreshLayout(for: attachment)
    }

    fileprivate func removeFailedMedia() {
        let failedMediaIDs = mediaProgressCoordinator.failedMediaIDs
        for mediaID in failedMediaIDs {
            richTextView.remove(attachmentID: mediaID)
            mediaProgressCoordinator.cancelAndStopTrack(of: mediaID)
        }
    }

    fileprivate func processVideoPressAttachments() {
        richTextView.textStorage.enumerateAttachments { (attachment, range) in
            if let videoAttachment = attachment as? VideoAttachment,
               let videoSrcURL = videoAttachment.srcURL,
               videoSrcURL.scheme == VideoProcessor.videoPressScheme,
               let videoPressID = videoSrcURL.host {
                // It's videoPress video so let's fetch the information for the video
                let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
                mediaService.getMediaURL(fromVideoPressID: videoPressID, in: self.post.blog, success: { (videoURLString, posterURLString) in
                    videoAttachment.srcURL = URL(string:videoURLString)
                    if let validPosterURLString = posterURLString, let posterURL = URL(string: validPosterURLString) {
                        videoAttachment.posterURL = posterURL
                    }
                    self.richTextView.refreshLayout(for: videoAttachment)
                }, failure: { (error) in
                    DDLogError("Unable to find information for VideoPress video with ID = \(videoPressID). Details: \(error.localizedDescription)")
                })
            } else if let videoAttachment = attachment as? VideoAttachment,
                let videoSrcURL = videoAttachment.srcURL,
                videoAttachment.posterURL == nil {
                let asset = AVURLAsset(url: videoSrcURL as URL, options: nil)
                let imgGenerator = AVAssetImageGenerator(asset: asset)
                imgGenerator.maximumSize = .zero
                imgGenerator.appliesPreferredTrackTransform = true
                let timeToCapture = NSValue(time: CMTimeMake(0, 1))
                imgGenerator.generateCGImagesAsynchronously(forTimes: [timeToCapture],
                                                            completionHandler: { (time, cgImage, actualTime, result, error) in
                    guard let cgImage = cgImage else {
                        return
                    }
                    let uiImage = UIImage(cgImage: cgImage)
                    let url = self.URLForTemporaryFileWithFileExtension(".jpg")
                    do {
                        try uiImage.writeJPEGToURL(url)
                        DispatchQueue.main.async {
                            videoAttachment.posterURL = url
                            self.richTextView.refreshLayout(for: videoAttachment)
                        }
                    } catch {
                        DDLogError("Unable to grab frame from video = \(videoSrcURL). Details: \(error.localizedDescription)")
                    }
                })
            }
        }
    }

    private func URLForTemporaryFileWithFileExtension(_ fileExtension: String) -> URL {
        assert(!fileExtension.isEmpty, "file Extension cannot be empty")
        let fileName = "\(ProcessInfo.processInfo.globallyUniqueString)_file.\(fileExtension)"
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        return fileURL
    }

    // TODO: Extract these strings into structs like other items
    fileprivate func displayActions(forAttachment attachment: MediaAttachment, position: CGPoint) {
        let mediaID = attachment.identifier
        let title: String = NSLocalizedString("Media Options", comment: "Title for action sheet with media options.")
        var message: String?
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alertController.addActionWithTitle(NSLocalizedString("Dismiss", comment: "User action to dismiss media options."),
                                           style: .cancel,
                                           handler: { (action) in
                                            if attachment == self.currentSelectedAttachment {
                                                self.currentSelectedAttachment = nil
                                                attachment.clearAllOverlays()
                                                self.richTextView.refreshLayout(for: attachment)
                                            }
        })
        if let imageAttachment = attachment as? ImageAttachment {
            alertController.preferredAction = alertController.addActionWithTitle(NSLocalizedString("Details", comment: "User action to edit media details."),
                                               style: .default,
                                               handler: { (action) in
                                                self.displayDetails(forAttachment: imageAttachment)
            })
        }
        // Is upload still going?
        if let mediaProgress = mediaProgressCoordinator.mediaUploading[mediaID],
            mediaProgress.completedUnitCount < mediaProgress.totalUnitCount {
            alertController.addActionWithTitle(NSLocalizedString("Stop Upload", comment: "User action to stop upload."),
                                               style: .destructive,
                                               handler: { (action) in
                                                mediaProgress.cancel()
                                                self.richTextView.remove(attachmentID: mediaID)
            })
        } else {
            if let error = mediaProgressCoordinator.error(forMediaID: mediaID) {
                message = error.localizedDescription
                alertController.addActionWithTitle(NSLocalizedString("Retry Upload", comment: "User action to retry media upload."),
                                                   style: .default,
                                                   handler: { (action) in
                                                    //retry upload
                                                    if let media = self.mediaProgressCoordinator.object(forMediaID: mediaID) as? Media,
                                                        let attachment = self.richTextView.attachment(withId: mediaID) {
                                                        attachment.clearAllOverlays()
                                                        attachment.progress = 0
                                                        self.richTextView.refreshLayout(for: attachment)
                                                        self.mediaProgressCoordinator.track(numberOfItems: 1)

                                                        WPAppAnalytics.track(.editorUploadMediaRetried, withProperties: [WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: self.post.blog)

                                                        self.upload(media: media, mediaID: mediaID)
                                                    }
                })
            }
            alertController.addActionWithTitle(NSLocalizedString("Remove Media", comment: "User action to remove media."),
                                               style: .destructive,
                                               handler: { (action) in
                                                self.richTextView.remove(attachmentID: mediaID)
            })
        }

        alertController.title = title
        alertController.message = message
        alertController.popoverPresentationController?.sourceView = richTextView
        alertController.popoverPresentationController?.sourceRect = CGRect(origin: position, size: CGSize(width: 1, height: 1))
        alertController.popoverPresentationController?.permittedArrowDirections = .any
        present(alertController, animated:true, completion: { () in
            UIMenuController.shared.setMenuVisible(false, animated: false)
        })
    }

    func displayDetails(forAttachment attachment: ImageAttachment) {
        let controller = AztecAttachmentViewController()
        controller.delegate = self
        controller.attachment = attachment
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true, completion: nil)

        WPAppAnalytics.track(.editorEditedImage, withProperties: [WPAppAnalyticsKeyEditorSource: Analytics.editorSource], with: post)
    }

    var mediaMessageAttributes: [String: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 1, height: 1)
        shadow.shadowColor = UIColor(white: 0, alpha: 0.6)
        let attributes: [String:Any] = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 20),
                                        NSParagraphStyleAttributeName: paragraphStyle,
                                        NSForegroundColorAttributeName: UIColor.white,
                                        NSShadowAttributeName: shadow]
        return attributes
    }

    func placeholderImage(for attachment: NSTextAttachment) -> UIImage {
        let imageSize = CGSize(width:128, height:128)
        let placeholderImage: UIImage
        switch attachment {
        case _ as ImageAttachment:
            placeholderImage = Gridicon.iconOfType(.image, withSize: imageSize)
        case _ as VideoAttachment:
            placeholderImage = Gridicon.iconOfType(.video, withSize: imageSize)
        default:
            placeholderImage = Gridicon.iconOfType(.attachment, withSize: imageSize)

        }

        return placeholderImage
    }
}


// AztecAttachmentViewController Delegate Conformance
//
extension AztecPostViewController: AztecAttachmentViewControllerDelegate {

    func aztecAttachmentViewController(_ viewController: AztecAttachmentViewController, changedAttachment: ImageAttachment) {
        richTextView.update(attachment: changedAttachment, alignment: changedAttachment.alignment, size: changedAttachment.size, url: changedAttachment.url!)
    }
}


// MARK: - TextViewAttachmentDelegate Conformance
//
extension AztecPostViewController: TextViewAttachmentDelegate {

    public func textView(_ textView: TextView, selected attachment: NSTextAttachment, atPosition position: CGPoint) {
        if !richTextView.isFirstResponder {
            richTextView.becomeFirstResponder()
        }

        switch attachment {
        case let attachment as HTMLAttachment:
            displayUnknownHtmlEditor(for: attachment)
        case let attachment as ImageAttachment:
            selected(textAttachment: attachment, atPosition: position)
        case let attachment as VideoAttachment:
            if let imageAttachment = currentSelectedAttachment {
                deselected(textAttachment: imageAttachment, atPosition: position)
            }
            selected(videoAttachment: attachment, atPosition: position)
        default:
            break
        }
    }

    func selected(textAttachment attachment: ImageAttachment, atPosition position: CGPoint) {
        //check if it's the current selected attachment or an failed upload
        if attachment == currentSelectedAttachment || mediaProgressCoordinator.error(forMediaID: attachment.identifier) != nil {
            //if it's the same attachment has before let's display the options
            displayActions(forAttachment: attachment, position: position)
        } else {
            // if it's a new attachment tapped let's unmark the previous one
            if let selectedAttachment = currentSelectedAttachment {
                selectedAttachment.clearAllOverlays()
                richTextView.refreshLayout(for: selectedAttachment)
            }
            // and mark the newly tapped attachment
            let message = NSLocalizedString("Tap for options", comment: "Message to overlay on top of a image to show when tapping on a image on the post/page editor.")
            attachment.message = NSAttributedString(string: message, attributes: mediaMessageAttributes)
            attachment.overlayImage = Gridicon.iconOfType(.pencil)
            richTextView.refreshLayout(for: attachment)
            currentSelectedAttachment = attachment
        }
    }

    func selected(videoAttachment: VideoAttachment, atPosition position: CGPoint) {
        if mediaProgressCoordinator.error(forMediaID: videoAttachment.identifier) != nil || mediaProgressCoordinator.isMediaUploading(mediaID: videoAttachment.identifier) {
            displayActions(forAttachment: videoAttachment, position: position)
            return
        }
        guard let videoURL = videoAttachment.srcURL else {
            return
        }
        if let videoPressID = videoAttachment.videoPressID {
            // It's videoPress video so let's fetch the information for the video
            let mediaService = MediaService(managedObjectContext:ContextManager.sharedInstance().mainContext)
            mediaService.getMediaURL(fromVideoPressID: videoPressID, in: self.post.blog, success: { (videoURLString, posterURLString) in
                guard let videoURL = URL(string:videoURLString) else {
                    return
                }
                videoAttachment.srcURL = videoURL
                if let validPosterURLString = posterURLString, let posterURL = URL(string: validPosterURLString) {
                    videoAttachment.posterURL = posterURL
                }
                self.richTextView.refreshLayout(for: videoAttachment)
                self.displayVideoPlayer(for: videoURL)
            }, failure: { (error) in
                DDLogError("Unable to find information for VideoPress video with ID = \(videoPressID). Details: \(error.localizedDescription)")
            })
        } else {
            displayVideoPlayer(for: videoURL)
        }
    }

    func displayVideoPlayer(for videoURL: URL) {
        let asset = AVURLAsset(url: videoURL)
        let controller = AVPlayerViewController()
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        controller.showsPlaybackControls = true
        controller.player = player
        player.play()
        present(controller, animated:true, completion: nil)
    }


    public func textView(_ textView: TextView, deselected attachment: NSTextAttachment, atPosition position: CGPoint) {
        deselected(textAttachment: attachment, atPosition: position)
    }

    func deselected(textAttachment attachment: NSTextAttachment, atPosition position: CGPoint) {
        currentSelectedAttachment = nil
        if let mediaAttachment = attachment as? MediaAttachment {
            mediaAttachment.clearAllOverlays()
            richTextView.refreshLayout(for: mediaAttachment)
        }
    }

    func textView(_ textView: TextView, attachment: NSTextAttachment, imageAt url: URL, onSuccess success: @escaping (UIImage) -> Void, onFailure failure: @escaping (Void) -> Void) -> UIImage {
        var requestURL = url
        let imageMaxDimension = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        //use height zero to maintain the aspect ratio when fetching
        var size = CGSize(width: imageMaxDimension, height: 0)
        let request: URLRequest
        if url.isFileURL {
            request = URLRequest(url: url)
        } else if self.post.blog.isPrivate() {
            // private wpcom image needs special handling.
            // the size that WPImageHelper expects is pixel size
            size.width = size.width * UIScreen.main.scale
            requestURL = WPImageURLHelper.imageURLWithSize(size, forImageURL: requestURL)
            request = PrivateSiteURLProtocol.requestForPrivateSite(from: requestURL)
        } else {
            // the size that PhotonImageURLHelper expects is points size
            requestURL = PhotonImageURLHelper.photonURL(with: size, forImageURL: requestURL)
            request = URLRequest(url: requestURL)
        }

        let imageDownloader = AFImageDownloader.defaultInstance()
        let receipt = imageDownloader.downloadImage(for: request, success: { (request, response, image) in
            DispatchQueue.main.async(execute: {
                success(image)
            })
        }) { (request, response, error) in
            DispatchQueue.main.async(execute: {
                failure()
            })
        }

        if let receipt = receipt {
            activeMediaRequests.append(receipt)
        }

        return placeholderImage(for: attachment)
    }

    func textView(_ textView: TextView, urlFor imageAttachment: ImageAttachment) -> URL {
        saveToMedia(attachment: imageAttachment)
        return URL(string:"placeholder://")!
    }

    func cancelAllPendingMediaRequests() {
        let imageDownloader = AFImageDownloader.defaultInstance()
        for receipt in activeMediaRequests {
            imageDownloader.cancelTask(for: receipt)
        }
    }

    func textView(_ textView: TextView, deletedAttachmentWith attachmentID: String) {
        mediaProgressCoordinator.cancelAndStopTrack(of:attachmentID)
    }

    func textView(_ textView: TextView, placeholderForAttachment attachment: NSTextAttachment) -> UIImage {
        return placeholderImage(for: attachment)
    }
}


// MARK: - MediaPickerViewController Delegate Conformance
//
extension AztecPostViewController: WPMediaPickerViewControllerDelegate {

    func mediaPickerControllerDidCancel(_ picker: WPMediaPickerViewController) {
        dismiss(animated: true, completion: nil)
        richTextView.becomeFirstResponder()
    }

    func mediaPickerController(_ picker: WPMediaPickerViewController, didFinishPickingAssets assets: [Any]) {
        dismiss(animated: true, completion: nil)
        richTextView.becomeFirstResponder()

        if assets.isEmpty {
            return
        }

        mediaProgressCoordinator.track(numberOfItems: assets.count)
        for asset in assets {
            switch asset {
            case let phAsset as PHAsset:
                insertDeviceMedia(phAsset: phAsset)
            case let media as Media:
                insertSiteMediaLibrary(media: media)
            default:
                continue
            }
        }

    }
}

// MARK: - State Restoration
//
extension AztecPostViewController: UIViewControllerRestoration {
    class func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        return restoreAztec(withCoder: coder)
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(post.objectID.uriRepresentation(), forKey: Restoration.postIdentifierKey)
        coder.encode(shouldRemovePostOnDismiss, forKey: Restoration.shouldRemovePostKey)
    }

    class func restoreAztec(withCoder coder: NSCoder) -> AztecPostViewController? {
        let context = ContextManager.sharedInstance().mainContext
        guard let postURI = coder.decodeObject(forKey: Restoration.postIdentifierKey) as? URL,
            let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: postURI) else {
                return nil
        }

        let post = try? context.existingObject(with: objectID)
        guard let restoredPost = post as? AbstractPost else {
            return nil
        }

        let aztecViewController = AztecPostViewController(post: restoredPost)
        aztecViewController.shouldRemovePostOnDismiss = coder.decodeBool(forKey: Restoration.shouldRemovePostKey)

        return aztecViewController
    }
}


// MARK: - Constants
//
extension AztecPostViewController {

    struct Analytics {
        static let editorSource             = "aztec"
        static let headerStyleValues = ["none", "h1", "h2", "h3", "h4", "h5", "h6"]
    }

    struct Assets {
        static let closeButtonModalImage    = Gridicon.iconOfType(.cross)
        static let closeButtonRegularImage  = UIImage(named: "icon-posts-editor-chevron")
        static let defaultMissingImage      = Gridicon.iconOfType(.image)
    }

    struct Constants {
        static let defaultMargin            = CGFloat(20)
        static let separatorButtonWidth     = CGFloat(-12)
        static let cancelButtonPadding      = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 5)
        static let blogPickerCompactSize    = CGSize(width: 125, height: 30)
        static let blogPickerRegularSize    = CGSize(width: 300, height: 30)
        static let moreAttachmentText       = "more"
        static let placeholderPadding       = UIEdgeInsets(top: 8, left: 5, bottom: 0, right: 0)
        static let headers                  = [Header.HeaderType.none, .h1, .h2, .h3, .h4, .h5, .h6]
        static let lists                    = [TextList.Style.unordered, .ordered]
    }

    struct MoreSheetAlert {
        static let htmlTitle                = NSLocalizedString("Switch to HTML", comment: "Switches the Editor to HTML Mode")
        static let richTitle                = NSLocalizedString("Switch to Rich Text", comment: "Switches the Editor to Rich Text Mode")
        static let previewTitle             = NSLocalizedString("Preview", comment: "Displays the Post Preview Interface")
        static let optionsTitle             = NSLocalizedString("Options", comment: "Displays the Post's Options")
        static let cancelTitle              = NSLocalizedString("Cancel", comment: "Dismisses the Alert from Screen")
    }

    struct Colors {
        static let aztecBackground          = UIColor.clear
        static let title                    = WPStyleGuide.grey()
        static let separator                = WPStyleGuide.greyLighten30()
        static let placeholder              = WPStyleGuide.grey()
        static let progressBackground       = WPStyleGuide.wordPressBlue()
        static let progressTint             = UIColor.white
        static let progressTrack            = WPStyleGuide.wordPressBlue()
        static let mediaProgressOverlay = UIColor(white: 1, alpha: 0.6)
        static let mediaProgressBarBackground = WPStyleGuide.lightGrey()
        static let mediaProgressBarTrack = WPStyleGuide.wordPressBlue()
    }

    struct Fonts {
        static let regular                  = WPFontManager.notoRegularFont(ofSize: 16)
        static let semiBold                 = WPFontManager.systemSemiBoldFont(ofSize: 16)
        static let title                    = WPFontManager.notoBoldFont(ofSize: 24.0)
        static let blogPicker               = Fonts.semiBold
    }

    struct Restoration {
        static let restorationIdentifier    = "AztecPostViewController"
        static let postIdentifierKey        = AbstractPost.classNameWithoutNamespaces()
        static let shouldRemovePostKey      = "shouldRemovePostOnDismiss"
    }

    struct SwitchSiteAlert {
        static let title                    = NSLocalizedString("Change Site", comment: "Title of an alert prompting the user that they are about to change the blog they are posting to.")
        static let message                  = NSLocalizedString("Choosing a different site will lose edits to site specific content like media and categories. Are you sure?", comment: "And alert message warning the user they will loose blog specific edits like categories, and media if they change the blog being posted to.")

        static let acceptTitle              = NSLocalizedString("OK", comment: "Accept Action")
        static let cancelTitle              = NSLocalizedString("Cancel", comment: "Cancel Action")
    }

    struct MediaUploadingAlert {
        static let title = NSLocalizedString("Uploading media", comment: "Title for alert when trying to save/exit a post before media upload process is complete.")
        static let message = NSLocalizedString("You are currently uploading media. Please wait until this completes.", comment: "This is a notification the user receives if they are trying to save a post (or exit) before the media upload process is complete.")
        static let acceptTitle  = NSLocalizedString("OK", comment: "Accept Action")
    }

    struct FailedMediaRemovalAlert {
        static let title = NSLocalizedString("Uploads failed", comment: "Title for alert when trying to save post with failed media items")
        static let message = NSLocalizedString("Some media uploads failed. This action will remove all failed media from the post.\nSave anyway?", comment: "Confirms with the user if they save the post all media that failed to upload will be removed from it.")
        static let acceptTitle  = NSLocalizedString("Yes", comment: "Accept Action")
        static let cancelTitle  = NSLocalizedString("Not Now", comment: "Nicer dialog answer for \"No\".")
    }
}

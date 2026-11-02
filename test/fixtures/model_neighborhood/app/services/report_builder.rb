class ReportBuilder
  def orders; ::Order.all; end
  def counted; ::Order.count; end
  def saved_marker; 'saved_a'; end
end

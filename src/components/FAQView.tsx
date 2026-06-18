import { useState } from 'react';
import { ChevronDown, ChevronUp, HelpCircle, Users, CreditCard, Package, Shield, Globe, TrendingUp } from 'lucide-react';

type FAQViewProps = {
  onViewChange: (view: string) => void;
};

type FAQItem = {
  question: string;
  answer: string;
  category: 'general' | 'pickers' | 'collectors' | 'payments' | 'shipping';
};

const faqs: FAQItem[] = [
  {
    category: 'general',
    question: 'What is SouvenirPickers?',
    answer: 'SouvenirPickers is a global marketplace that connects collectors with local pickers around the world. Collectors can request unique souvenirs from any location, while pickers earn money by sourcing and shipping authentic items from their region.'
  },
  {
    category: 'general',
    question: 'How does SouvenirPickers work?',
    answer: 'Collectors post requests for specific souvenirs or browse existing listings from pickers. Pickers can accept requests or create their own listings. Once an order is placed, payment is held in escrow while the picker sources and ships the item. After delivery confirmation, the picker receives payment.'
  },
  {
    category: 'general',
    question: 'Is SouvenirPickers available worldwide?',
    answer: 'Yes! SouvenirPickers operates in 150+ countries. We have pickers in major cities and remote locations around the globe, ready to help you find authentic souvenirs from virtually anywhere.'
  },
  {
    category: 'collectors',
    question: 'How do I request a souvenir as a collector?',
    answer: 'Simply create a collector account, navigate to the "Desires" section, and post your request. Describe what you\'re looking for, specify the location or region, set your budget, and pickers in that area will respond with offers.'
  },
  {
    category: 'collectors',
    question: 'How much do souvenirs typically cost?',
    answer: 'Prices vary based on the item, location, and shipping distance. Most souvenirs range from $10-$100, plus shipping costs. You can set your own budget when posting a request, and pickers will respond with offers within your range.'
  },
  {
    category: 'collectors',
    question: 'How long does it take to receive my souvenir?',
    answer: 'Delivery times vary by location and shipping method. Most orders are sourced within 3-7 days, and shipping typically takes 7-21 days depending on the origin country. Pickers will provide estimated timelines when accepting your request.'
  },
  {
    category: 'collectors',
    question: 'What if I\'m not satisfied with my order?',
    answer: 'All orders are protected by our escrow system. If the item doesn\'t match the description or arrives damaged, you can open a dispute within 7 days of delivery. Our support team will review the case and facilitate a resolution, which may include a refund or replacement.'
  },
  {
    category: 'pickers',
    question: 'How do I become a picker?',
    answer: 'Sign up for a picker account, complete your profile with your location and specialties, and optionally add portfolio photos or videos. After a 60-day free trial, there\'s a monthly subscription of $5 to remain active and access client requests.'
  },
  {
    category: 'pickers',
    question: 'How much can I earn as a picker?',
    answer: 'Earnings vary based on your activity level and location. Active pickers typically earn $500-$5,000+ per month. You set your own prices and keep 90% of each sale (a 10% platform commission applies). Plus the $5 monthly subscription. There\'s no cap on earnings.'
  },
  {
    category: 'pickers',
    question: 'Do I need to carry inventory?',
    answer: 'No! You only source items after receiving confirmed orders. Browse client requests, accept ones you can fulfill, and purchase the items locally before shipping. This is a zero-inventory business model.'
  },
  {
    category: 'pickers',
    question: 'What are the requirements to be a picker?',
    answer: 'You need to be 18+, have access to local markets or stores in your region, and be able to ship items internationally. You\'ll also need a payment method to receive earnings (bank account or PayPal) and a way to purchase shipping labels.'
  },
  {
    category: 'pickers',
    question: 'How do I get paid as a picker?',
    answer: 'Payments are held in escrow until the collector confirms delivery. Once confirmed (or automatically after 7 days), funds are released to your account minus the 10% platform commission. You can withdraw earnings to your connected bank account or PayPal at any time.'
  },
  {
    category: 'pickers',
    question: 'What if a collector disputes an order?',
    answer: 'If a collector opens a dispute, provide photos and documentation of the item you shipped. Our support team reviews all evidence from both sides and makes a fair decision. Maintaining high ratings and clear communication helps prevent disputes.'
  },
  {
    category: 'payments',
    question: 'What payment methods do you accept?',
    answer: 'We accept all major credit and debit cards (Visa, Mastercard, American Express, Discover) through our secure Stripe integration. Payments are processed securely and protected by industry-standard encryption.'
  },
  {
    category: 'payments',
    question: 'Is my payment information secure?',
    answer: 'Absolutely. We use Stripe for payment processing, which is certified to the highest industry standards. We never store your full credit card information on our servers. All transactions are encrypted and PCI-DSS compliant.'
  },
  {
    category: 'payments',
    question: 'What is the escrow system?',
    answer: 'When you place an order, payment is held securely in escrow. The picker receives payment only after you confirm delivery or automatically after 7 days. This protects both collectors (ensuring they receive their item) and pickers (ensuring they get paid for their work).'
  },
  {
    category: 'payments',
    question: 'Are there any hidden fees?',
    answer: 'No hidden fees. Collectors pay the price agreed upon with the picker plus any applicable taxes. Pickers pay a $5 monthly subscription after their 60-day free trial plus a 10% commission on all sales.'
  },
  {
    category: 'payments',
    question: 'What is the platform commission for pickers?',
    answer: 'Pickers pay a 10% commission on all sales. This commission covers payment processing fees, buyer protection through our escrow system, platform maintenance, and customer support. You keep 90% of every sale you make.'
  },
  {
    category: 'payments',
    question: 'Can I get a refund?',
    answer: 'Refunds are handled on a case-by-case basis. If an item doesn\'t match the description, arrives damaged, or never arrives, you can open a dispute within 7 days of delivery. Our support team will review and facilitate an appropriate resolution.'
  },
  {
    category: 'shipping',
    question: 'Who handles shipping?',
    answer: 'Pickers are responsible for packaging and shipping items to collectors. They choose the shipping carrier and method based on the item size, destination, and agreed timeline. Tracking information is provided for all shipments.'
  },
  {
    category: 'shipping',
    question: 'How much does shipping cost?',
    answer: 'Shipping costs vary by item size, weight, origin, and destination. Pickers typically provide shipping quotes when responding to requests. International shipping generally ranges from $10-$50 for small items and more for larger packages.'
  },
  {
    category: 'shipping',
    question: 'Do I have to pay customs or import duties?',
    answer: 'International shipments may be subject to customs duties, taxes, or fees imposed by your country. These charges are the responsibility of the buyer and are not included in the item price. Check your local customs regulations for specific requirements.'
  },
  {
    category: 'shipping',
    question: 'Can I track my shipment?',
    answer: 'Yes! Pickers provide tracking numbers for all shipments. You can view tracking updates in your order details within the SouvenirPickers platform. You\'ll receive notifications when your item ships and when it\'s delivered.'
  },
  {
    category: 'general',
    question: 'How do ratings and reviews work?',
    answer: 'After each completed order, both collectors and pickers can leave ratings and reviews. These reviews are public and help build trust in the community. Pickers with higher ratings tend to receive more requests and build better reputations.'
  },
  {
    category: 'general',
    question: 'What if I have a problem with an order?',
    answer: 'Contact our support team through the platform messaging system or email support@souvenirpickers.com. We typically respond within 24 hours and work to resolve issues fairly for both parties.'
  },
  {
    category: 'general',
    question: 'Is there a mobile app?',
    answer: 'Currently, SouvenirPickers is available as a responsive web application that works on all devices. A dedicated mobile app is in development and will be available soon.'
  }
];

export function FAQView({ onViewChange }: FAQViewProps) {
  const [expandedIndex, setExpandedIndex] = useState<number | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  const toggleQuestion = (index: number) => {
    setExpandedIndex(expandedIndex === index ? null : index);
  };

  const filteredFaqs = selectedCategory === 'all'
    ? faqs
    : faqs.filter(faq => faq.category === selectedCategory);

  const categories = [
    { id: 'all', label: 'All Questions', icon: HelpCircle },
    { id: 'general', label: 'General', icon: Globe },
    { id: 'collectors', label: 'For Collectors', icon: Users },
    { id: 'pickers', label: 'For Pickers', icon: TrendingUp },
    { id: 'payments', label: 'Payments', icon: CreditCard },
    { id: 'shipping', label: 'Shipping', icon: Package }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="text-center mb-12">
          <div className="flex justify-center mb-6">
            <div className="bg-gradient-to-br from-blue-500 to-blue-600 p-6 rounded-3xl shadow-xl">
              <HelpCircle className="w-16 h-16 text-white" />
            </div>
          </div>
          <h1 className="text-5xl font-extrabold text-gray-900 mb-4">
            Frequently Asked Questions
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            Find answers to common questions about SouvenirPickers
          </p>
        </div>

        <div className="flex flex-wrap gap-3 justify-center mb-12">
          {categories.map((category) => {
            const Icon = category.icon;
            return (
              <button
                key={category.id}
                onClick={() => {
                  setSelectedCategory(category.id);
                  setExpandedIndex(null);
                }}
                className={`flex items-center gap-2 px-6 py-3 rounded-xl font-semibold transition-all duration-300 ${
                  selectedCategory === category.id
                    ? 'bg-gradient-to-r from-blue-600 to-blue-700 text-white shadow-lg'
                    : 'bg-white text-gray-700 hover:bg-gray-50 shadow'
                }`}
              >
                <Icon className="w-5 h-5" />
                {category.label}
              </button>
            );
          })}
        </div>

        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <div className="space-y-4">
            {filteredFaqs.map((faq, index) => (
              <div
                key={index}
                className="border border-gray-200 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-md"
              >
                <button
                  onClick={() => toggleQuestion(index)}
                  className="w-full flex items-center justify-between p-6 text-left hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-start gap-4 flex-1">
                    <div className={`mt-1 p-2 rounded-lg ${
                      faq.category === 'general' ? 'bg-blue-100' :
                      faq.category === 'collectors' ? 'bg-orange-100' :
                      faq.category === 'pickers' ? 'bg-green-100' :
                      faq.category === 'payments' ? 'bg-purple-100' :
                      'bg-teal-100'
                    }`}>
                      <Shield className={`w-5 h-5 ${
                        faq.category === 'general' ? 'text-blue-600' :
                        faq.category === 'collectors' ? 'text-orange-600' :
                        faq.category === 'pickers' ? 'text-green-600' :
                        faq.category === 'payments' ? 'text-purple-600' :
                        'text-teal-600'
                      }`} />
                    </div>
                    <h3 className="text-lg font-bold text-gray-900 flex-1">
                      {faq.question}
                    </h3>
                  </div>
                  <div className="ml-4">
                    {expandedIndex === index ? (
                      <ChevronUp className="w-6 h-6 text-blue-600" />
                    ) : (
                      <ChevronDown className="w-6 h-6 text-gray-400" />
                    )}
                  </div>
                </button>
                {expandedIndex === index && (
                  <div className="px-6 pb-6 pl-20">
                    <p className="text-gray-700 leading-relaxed text-base">
                      {faq.answer}
                    </p>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-2xl p-8 shadow-xl text-center">
          <h2 className="text-3xl font-bold mb-4">Still have questions?</h2>
          <p className="text-blue-100 text-lg mb-6">
            Can't find the answer you're looking for? Our support team is here to help.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <button
              onClick={() => onViewChange('messages')}
              className="bg-white text-blue-600 px-8 py-3 rounded-xl font-bold hover:bg-blue-50 transition-all duration-300 shadow-lg"
            >
              Contact Support
            </button>
            <button
              onClick={() => onViewChange('home')}
              className="bg-blue-500 text-white px-8 py-3 rounded-xl font-bold hover:bg-blue-400 transition-all duration-300 border-2 border-white border-opacity-30"
            >
              Back to Home
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
